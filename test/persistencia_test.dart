import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:climasense/models/ocorrencia.dart';
import 'package:climasense/providers/dados_app.dart';
import 'package:climasense/services/banco_ocorrencias.dart';
import 'package:climasense/services/nuvem_ocorrencias.dart';
import 'package:climasense/services/sincronizador_ocorrencias.dart';

class NuvemTeste implements NuvemOcorrencias {
  @override
  bool configurada = true;
  String usuario = 'demo/usuario1';
  bool offline = false, falharAposSalvar = false;
  Completer<String>? conexao;
  int conexoes = 0, envios = 0;
  final registros = <String, Ocorrencia>{};
  @override
  Future<String> conectar() async {
    conexoes++;
    if (offline) throw Exception('Sem rede');
    return conexao == null ? usuario : await conexao!.future;
  }

  @override
  Future<void> enviar(Ocorrencia item) async {
    envios++;
    registros[item.id] = item;
    if (falharAposSalvar) throw TimeoutException('Confirmação não recebida');
  }

  @override
  Future<List<Ocorrencia>> listar() async => registros.values.toList();
  @override
  Future<void> excluir(String id) async {
    registros.remove(id);
  }
}

Ocorrencia item(
  String id, {
  String descricao = 'Alagamento observado na rua.',
}) => Ocorrencia(id, 'Centro', 'Alagamento', descricao, DateTime(2026, 11, 15));
Future<BancoOcorrencias> memoria() async =>
    BancoOcorrencias(await newDatabaseFactoryMemory().openDatabase('teste'));
Future<void> aguardar(bool Function() condicao) async {
  for (var i = 0; i < 500; i++) {
    if (condicao()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('A operação não terminou no tempo esperado.');
}

void main() {
  test(
    'banco em arquivo preserva ocorrências e fila após fechar e reabrir',
    () async {
      final pasta = await Directory.systemTemp.createTemp('climasense_banco_');
      final caminho = '${pasta.path}/climasense.db';
      try {
        var banco = BancoOcorrencias(
          await databaseFactoryIo.openDatabase(caminho),
        );
        await banco.adicionar(item('1'));
        await banco.fechar();
        banco = BancoOcorrencias(await databaseFactoryIo.openDatabase(caminho));
        expect((await banco.listar()).single.id, '1');
        expect((await banco.listar(somentePendentes: true)).single.id, '1');
        await banco.confirmarEnvio('1');
        await banco.fechar();
        banco = BancoOcorrencias(await databaseFactoryIo.openDatabase(caminho));
        expect(await banco.listar(somentePendentes: true), isEmpty);
        expect(await banco.listar(), hasLength(1));
        await banco.editar(item('1', descricao: 'Descrição corrigida.'));
        await banco.fechar();
        banco = BancoOcorrencias(await databaseFactoryIo.openDatabase(caminho));
        expect((await banco.listar()).single.descricao, 'Descrição corrigida.');
        expect((await banco.listarPendencias()).single.exclusao, isFalse);
        await banco.excluir('1');
        await banco.fechar();
        banco = BancoOcorrencias(await databaseFactoryIo.openDatabase(caminho));
        expect(await banco.listar(), isEmpty);
        expect((await banco.listarPendencias()).single.exclusao, isTrue);
        await banco.selecionarConta('primeira', preservar: true);
        await banco.selecionarConta('segunda', preservar: false);
        await banco.adicionar(item('2'));
        await banco.fechar();
        banco = BancoOcorrencias(await databaseFactoryIo.openDatabase(caminho));
        await banco.preparar();
        expect((await banco.listar()).single.id, '2');
        expect(await banco.precisaMigrar, isFalse);
        await banco.selecionarConta('primeira', preservar: false);
        expect(await banco.listar(), isEmpty);
        expect((await banco.listarPendencias()).single.id, '1');
        await banco.fechar();
      } finally {
        final raiz = Directory.systemTemp.absolute.path;
        final alvo = pasta.absolute.path;
        if (alvo.startsWith('$raiz${Platform.pathSeparator}') &&
            pasta.uri.pathSegments.any(
              (p) => p.startsWith('climasense_banco_'),
            )) {
          await pasta.delete(recursive: true);
        }
      }
    },
  );

  test('migração dos registros antigos acontece uma única vez', () async {
    final banco = await memoria();
    await banco.migrar([item('antigo')]);
    await banco.migrar([item('antigo'), item('nao-migrar-de-novo')]);
    expect((await banco.listar()).single.id, 'antigo');
    expect(await banco.precisaMigrar, isFalse);
    await banco.fechar();
  });

  test(
    'falha de conexão mantém pendências; nova tentativa envia e restaura dados',
    () async {
      final banco = await memoria();
      final nuvem = NuvemTeste()..offline = true;
      await banco.adicionar(item('local'));
      final sync = SincronizadorOcorrencias(banco, nuvem);
      await expectLater(sync.sincronizar(), throwsException);
      expect(await banco.listar(somentePendentes: true), hasLength(1));
      nuvem.offline = false;
      nuvem.registros['remoto'] = item('remoto');
      await sync.sincronizar();
      expect(await banco.listar(), hasLength(2));
      expect(await banco.listar(somentePendentes: true), isEmpty);
      await sync.sincronizar();
      expect(nuvem.envios, 1);
      await banco.fechar();
    },
  );

  test(
    'repetir envio após perda da confirmação não duplica a ocorrência',
    () async {
      final banco = await memoria();
      final nuvem = NuvemTeste()..falharAposSalvar = true;
      await banco.adicionar(item('1'));
      final sync = SincronizadorOcorrencias(banco, nuvem);
      await expectLater(sync.sincronizar(), throwsA(isA<TimeoutException>()));
      expect(await banco.listar(somentePendentes: true), hasLength(1));
      nuvem.falharAposSalvar = false;
      await sync.sincronizar();
      expect(nuvem.registros, hasLength(1));
      expect(await banco.listar(), hasLength(1));
      expect(await banco.listar(somentePendentes: true), isEmpty);
      await banco.fechar();
    },
  );

  test(
    'dados recebidos não sobrescrevem uma ocorrência local pendente',
    () async {
      final banco = await memoria();
      await banco.adicionar(item('1', descricao: 'Texto ainda não enviado.'));
      await banco.incorporar([item('1', descricao: 'Outro texto na nuvem.')]);
      expect(
        (await banco.listar()).single.descricao,
        'Texto ainda não enviado.',
      );
      expect(await banco.listar(somentePendentes: true), hasLength(1));
      await banco.fechar();
    },
  );

  test(
    'troca de conta bloqueia envio de dados locais para outro usuário',
    () async {
      final banco = await memoria();
      await banco.vincularUsuario('demo/outro-usuario');
      await banco.adicionar(item('1'));
      final nuvem = NuvemTeste();
      await expectLater(
        SincronizadorOcorrencias(banco, nuvem).sincronizar(),
        throwsStateError,
      );
      expect(nuvem.envios, 0);
      expect(await banco.listar(somentePendentes: true), hasLength(1));
      await banco.fechar();
    },
  );

  test(
    'provider migra Preferences e exige ativação explícita antes de enviar',
    () async {
      SharedPreferences.setMockInitialValues({
        'consentimento': true,
        'ocorrencias': jsonEncode([item('antigo').toJson()]),
      });
      final banco = await memoria();
      final nuvem = NuvemTeste();
      final dados = DadosApp(
        abrirBanco: () async => banco,
        nuvem: nuvem,
        intervaloSincronizacao: Duration.zero,
      );
      await dados.iniciar();
      await dados.adicionar(item('novo'));
      expect(dados.ocorrencias, hasLength(2));
      expect(nuvem.conexoes, 0);
      await dados.configurarNuvem(true);
      await aguardar(
        () => !dados.sincronizando && dados.ultimaSincronizacao != null,
      );
      expect(nuvem.registros, hasLength(2));
      expect(dados.pendentes, 0);
      dados.dispose();
    },
  );

  test(
    'salvar no aparelho não aguarda uma conexão Firebase pendente',
    () async {
      SharedPreferences.setMockInitialValues({
        'consentimento': true,
        'copia_nuvem': true,
      });
      final banco = await memoria();
      final nuvem = NuvemTeste()..conexao = Completer<String>();
      final dados = DadosApp(
        abrirBanco: () async => banco,
        nuvem: nuvem,
        intervaloSincronizacao: Duration.zero,
      );
      await dados.iniciar();
      await dados.adicionar(item('1')).timeout(const Duration(seconds: 1));
      expect(dados.ocorrencias.single.id, '1');
      expect(dados.pendentes, 1);
      nuvem.conexao!.complete(nuvem.usuario);
      await aguardar(() => !dados.sincronizando && dados.pendentes == 0);
      dados.dispose();
    },
  );

  test(
    'falha ao abrir banco permite tentar novamente sem apagar dados',
    () async {
      SharedPreferences.setMockInitialValues({});
      var tentativas = 0;
      final dados = DadosApp(
        abrirBanco: () async {
          tentativas++;
          if (tentativas == 1) throw Exception('Falha temporária');
          return memoria();
        },
      );
      await dados.iniciar();
      expect(dados.erroInicializacao, isNotNull);
      expect(dados.pronto, isFalse);
      await dados.iniciar();
      expect(dados.pronto, isTrue);
      expect(dados.erroInicializacao, isNull);
      dados.dispose();
    },
  );
}
