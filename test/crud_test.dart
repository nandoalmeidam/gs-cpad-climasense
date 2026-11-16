import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:climasense/app/climasense_app.dart';
import 'package:climasense/models/ocorrencia.dart';
import 'package:climasense/services/banco_ocorrencias.dart';
import 'package:climasense/services/nuvem_ocorrencias.dart';
import 'package:climasense/services/sincronizador_ocorrencias.dart';
import 'suporte/dados_teste.dart';

class NuvemCrud implements NuvemOcorrencias {
  @override
  bool configurada = true;
  bool offline = false;
  final registros = <String, Ocorrencia>{};
  Future<void> Function(Ocorrencia)? duranteEnvio;
  @override
  Future<String> conectar() async {
    if (offline) throw Exception('Sem conexão');
    return 'demo/usuario';
  }

  @override
  Future<void> enviar(Ocorrencia item) async {
    await duranteEnvio?.call(item);
    registros[item.id] = item;
  }

  @override
  Future<void> excluir(String id) async {
    registros.remove(id);
  }

  @override
  Future<List<Ocorrencia>> listar() async => registros.values.toList();
}

Ocorrencia criar({
  String bairro = 'Centro',
  String descricao = 'Registro inicial para o teste.',
}) => Ocorrencia(
  '1',
  bairro,
  'Alagamento',
  descricao,
  DateTime(2026, 11, 15, 10),
);
Future<BancoOcorrencias> memoria() async =>
    BancoOcorrencias(await newDatabaseFactoryMemory().openDatabase('crud'));

void main() {
  test(
    'exclusão sincronizada em um aparelho também é refletida no outro',
    () async {
      final primeiro = await memoria(), segundo = await memoria();
      final nuvem = NuvemCrud();
      final sync1 = SincronizadorOcorrencias(primeiro, nuvem);
      final sync2 = SincronizadorOcorrencias(segundo, nuvem);
      await primeiro.adicionar(criar());
      await sync1.sincronizar();
      await sync2.sincronizar();
      expect(await segundo.listar(), hasLength(1));
      await primeiro.excluir('1');
      await sync1.sincronizar();
      await sync2.sincronizar();
      expect(await segundo.listar(), isEmpty);
      expect(await segundo.listarPendencias(), isEmpty);
      await primeiro.fechar();
      await segundo.fechar();
    },
  );
  test('editar preserva ID e data e mantém apenas uma ocorrência', () async {
    final banco = await memoria();
    await banco.adicionar(criar());
    await banco.editar(criar(bairro: 'Jardim'));
    final atual = (await banco.listar()).single;
    expect(atual.id, '1');
    expect(atual.data, criar().data);
    expect(atual.bairro, 'Jardim');
    expect((await banco.listarPendencias()).single.revisao, 2);
    await banco.fechar();
  });
  test(
    'editar e excluir offline sincroniza depois sem recuperar o registro apagado',
    () async {
      final banco = await memoria();
      final nuvem = NuvemCrud();
      final sync = SincronizadorOcorrencias(banco, nuvem);
      await banco.adicionar(criar());
      await sync.sincronizar();
      nuvem.offline = true;
      await banco.editar(criar(bairro: 'Jardim'));
      await expectLater(sync.sincronizar(), throwsException);
      expect((await banco.listar()).single.bairro, 'Jardim');
      nuvem.offline = false;
      await sync.sincronizar();
      expect(nuvem.registros['1']!.bairro, 'Jardim');
      expect(nuvem.registros, hasLength(1));
      nuvem.offline = true;
      await banco.excluir('1');
      await expectLater(sync.sincronizar(), throwsException);
      expect(await banco.listar(), isEmpty);
      expect((await banco.listarPendencias()).single.exclusao, isTrue);
      await banco.incorporar([criar()]);
      expect(await banco.listar(), isEmpty);
      nuvem.offline = false;
      await sync.sincronizar();
      expect(nuvem.registros, isEmpty);
      expect(await banco.listarPendencias(), isEmpty);
      await banco.fechar();
    },
  );
  test(
    'confirmação de um envio antigo não limpa uma edição mais recente',
    () async {
      final banco = await memoria();
      final nuvem = NuvemCrud();
      await banco.adicionar(criar());
      nuvem.duranteEnvio = (_) => banco.editar(criar(bairro: 'Jardim'));
      final sync = SincronizadorOcorrencias(banco, nuvem);
      await sync.sincronizar();
      expect((await banco.listar()).single.bairro, 'Jardim');
      expect(await banco.listarPendencias(), hasLength(1));
      nuvem.duranteEnvio = null;
      await sync.sincronizar();
      expect(nuvem.registros['1']!.bairro, 'Jardim');
      expect(await banco.listarPendencias(), isEmpty);
      await banco.fechar();
    },
  );
  test(
    'exclusão durante envio não reaparece na resposta antiga do servidor',
    () async {
      final banco = await memoria();
      final nuvem = NuvemCrud();
      await banco.adicionar(criar());
      nuvem.duranteEnvio = (_) => banco.excluir('1');
      final sync = SincronizadorOcorrencias(banco, nuvem);
      await sync.sincronizar();
      expect(await banco.listar(), isEmpty);
      expect((await banco.listarPendencias()).single.exclusao, isTrue);
      nuvem.duranteEnvio = null;
      await sync.sincronizar();
      expect(nuvem.registros, isEmpty);
      expect(await banco.listarPendencias(), isEmpty);
      // Uma cópia antiga recebida posteriormente também deve continuar oculta.
      await banco.incorporar([criar()]);
      expect(await banco.listar(), isEmpty);
      expect((await banco.listarPendencias()).single.exclusao, isTrue);
      await banco.fechar();
    },
  );
  test(
    'formulário antigo não pode editar uma ocorrência já excluída',
    () async {
      final banco = await memoria();
      await banco.adicionar(criar());
      await banco.excluir('1');
      await expectLater(
        banco.editar(criar(bairro: 'Jardim')),
        throwsStateError,
      );
      expect(await banco.listar(), isEmpty);
      await banco.fechar();
    },
  );
  testWidgets('histórico edita, cancela exclusão e exclui após confirmar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'consentimento': true,
      'ocorrencias': jsonEncode([criar().toJson()]),
    });
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dados = criarDadosTeste();
    await tester.pumpWidget(ClimaSenseApp(dadosApp: dados));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    Future<void> menu(String titulo) async {
      await tester.scrollUntilVisible(
        find.text(titulo),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text(titulo)),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opções da ocorrência'));
      await tester.pumpAndSettle();
    }

    await menu('Alagamento · Centro');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar ocorrência'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Bairro'))
          .controller!
          .text,
      'Centro',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bairro'),
      'Jardim',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Descrição corrigida para o registro.',
    );
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(dados.ocorrencias, hasLength(1));
    expect(dados.ocorrencias.single.id, '1');
    expect(dados.ocorrencias.single.bairro, 'Jardim');
    expect(dados.ocorrencias.single.data, criar().data);
    await menu('Alagamento · Jardim');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir ocorrência?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(dados.ocorrencias, hasLength(1));
    await menu('Alagamento · Jardim');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(dados.ocorrencias, isEmpty);
    expect(find.text('Ocorrência excluída.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
