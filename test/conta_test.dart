import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:climasense/services/banco_ocorrencias.dart';
import 'package:climasense/services/nuvem_ocorrencias.dart';
import 'package:climasense/services/conta_service.dart';
import 'package:climasense/providers/dados_app.dart';
import 'package:climasense/models/ocorrencia.dart';
import 'package:climasense/features/conta/conta_page.dart';

class ContaTeste implements NuvemOcorrencias, ContaService {
  String uid = 'projeto/anonimo';
  @override
  String? email;
  @override
  bool get contaPermanente => email != null;
  @override
  bool get configurada => true;
  final areas = <String, Map<String, Ocorrencia>>{};
  Map<String, Ocorrencia> get registros => areas.putIfAbsent(uid, () => {});
  String? recuperacao;
  Completer<void>? aguardandoEnvio;
  Completer<void>? envioIniciado;
  @override
  Future<String> conectar() async => uid;
  @override
  Future<void> enviar(Ocorrencia item) async {
    if (envioIniciado?.isCompleted == false) envioIniciado!.complete();
    await aguardandoEnvio?.future;
    registros[item.id] = item;
  }

  @override
  Future<void> excluir(String id) async {
    registros.remove(id);
  }

  @override
  Future<List<Ocorrencia>> listar() async => registros.values.toList();
  @override
  Future<String> criarConta(String email, String senha) async {
    this.email = email;
    return uid;
  }

  @override
  Future<String> entrar(String email, String senha) async {
    this.email = email;
    uid = email == 'nova@example.com' ? 'projeto/nova' : 'projeto/anonimo';
    return uid;
  }

  @override
  Future<void> recuperarSenha(String email) async {
    recuperacao = email;
  }

  @override
  Future<void> sair() async {
    email = null;
    uid = 'projeto/visitante';
  }
}

Ocorrencia item(String id) => Ocorrencia(
  id,
  'Centro',
  'Alagamento',
  'Registro de teste local.',
  DateTime(2026, 11, 16),
);
Future<BancoOcorrencias> banco() async =>
    BancoOcorrencias(await newDatabaseFactoryMemory().openDatabase('contas'));
DadosApp provider(BancoOcorrencias db, ContaTeste conta) => DadosApp(
  abrirBanco: () async => db,
  nuvem: conta,
  intervaloSincronizacao: Duration.zero,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'consentimento': true}));
  test(
    'vincular conta mantém IDs, recuperar em outro banco e separar visitantes',
    () async {
      final nuvem = ContaTeste();
      final dados = provider(await banco(), nuvem);
      await dados.iniciar();
      await dados.adicionar(item('meu'));
      await dados.acessarConta(
        email: 'original@example.com',
        senha: 'senha123',
        criar: true,
      );
      expect(dados.ocorrencias.single.id, 'meu');
      expect(nuvem.registros.keys, contains('meu'));
      await dados.sairDaConta();
      expect(dados.ocorrencias, isEmpty);
      await dados.adicionar(item('visitante'));
      await dados.acessarConta(
        email: 'original@example.com',
        senha: 'senha123',
        criar: false,
      );
      expect(dados.ocorrencias.map((o) => o.id), ['meu']);
      expect(nuvem.registros.containsKey('visitante'), isFalse);
      await dados.sairDaConta();
      expect(dados.ocorrencias.single.id, 'visitante');
      // Outro aparelho começa com um banco vazio e recupera a cópia remota.
      final outro = provider(await banco(), nuvem);
      await outro.iniciar();
      await outro.acessarConta(
        email: 'original@example.com',
        senha: 'senha123',
        criar: false,
      );
      expect(outro.ocorrencias.single.id, 'meu');
      dados.dispose();
      outro.dispose();
    },
  );
  test('trocar entre duas contas não envia nem exibe dados da outra', () async {
    final nuvem = ContaTeste();
    final dados = provider(await banco(), nuvem);
    await dados.iniciar();
    await dados.adicionar(item('primeira'));
    await dados.acessarConta(
      email: 'original@example.com',
      senha: 'senha123',
      criar: true,
    );
    await dados.acessarConta(
      email: 'nova@example.com',
      senha: 'senha123',
      criar: false,
    );
    expect(dados.ocorrencias, isEmpty);
    expect(nuvem.registros, isEmpty);
    await dados.adicionar(item('segunda'));
    await dados.sincronizar();
    await dados.acessarConta(
      email: 'original@example.com',
      senha: 'senha123',
      criar: false,
    );
    expect(dados.ocorrencias.map((o) => o.id), ['primeira']);
    expect(nuvem.registros.containsKey('segunda'), isFalse);
    dados.dispose();
  });
  test(
    'troca de conta espera o envio atual antes de mudar a identidade',
    () async {
      final nuvem = ContaTeste();
      final dados = provider(await banco(), nuvem);
      await dados.iniciar();
      await dados.configurarNuvem(true);
      await dados.sincronizar();
      nuvem.aguardandoEnvio = Completer<void>();
      nuvem.envioIniciado = Completer<void>();
      await dados.adicionar(item('anterior'));
      await nuvem.envioIniciado!.future;
      final trocar = dados.acessarConta(
        email: 'nova@example.com',
        senha: 'senha123',
        criar: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(dados.alterandoConta, isTrue);
      expect(nuvem.uid, 'projeto/anonimo');
      nuvem.aguardandoEnvio!.complete();
      await trocar;
      expect(dados.ocorrencias, isEmpty);
      expect(nuvem.registros, isEmpty);
      expect(nuvem.areas['projeto/anonimo']!.containsKey('anterior'), isTrue);
      await dados.sairDaConta();
      expect(dados.ocorrencias.single.id, 'anterior');
      // O visitante pode vincular os próprios registros a uma nova conta.
      await dados.acessarConta(
        email: 'visitante@example.com',
        senha: 'senha123',
        criar: true,
      );
      expect(nuvem.registros.containsKey('anterior'), isTrue);
      await dados.sairDaConta();
      expect(dados.ocorrencias, isEmpty);
      dados.dispose();
    },
  );
  test('saída com pendências não desconecta nem oculta registros', () async {
    final nuvem = ContaTeste()..email = 'original@example.com';
    final dados = provider(await banco(), nuvem);
    await dados.iniciar();
    await dados.adicionar(item('pendente'));
    await expectLater(dados.sairDaConta(), throwsStateError);
    expect(nuvem.email, 'original@example.com');
    expect(dados.ocorrencias.single.id, 'pendente');
    expect(dados.alterandoConta, isFalse);
    dados.dispose();
  });
  testWidgets(
    'conta valida senha e permite solicitar recuperação sem exigir senha',
    (tester) async {
      final conta = ContaTeste();
      late DadosApp dados;
      await tester.runAsync(() async {
        dados = provider(await banco(), conta);
        await dados.iniciar();
      });
      await tester.pumpWidget(MaterialApp(home: ContaPage(dados: dados)));
      await tester.tap(find.text('Criar conta e sincronizar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      await tester.tap(find.text('Já tenho uma conta'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'original@example.com',
      );
      await tester.ensureVisible(find.text('Esqueci minha senha'));
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      expect(conta.recuperacao, 'original@example.com');
      expect(find.textContaining('Se houver uma conta'), findsOneWidget);
      dados.dispose();
    },
  );
}
