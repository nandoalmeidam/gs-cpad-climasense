import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:climasense/app/climasense_app.dart';
import 'package:climasense/core/theme/app_theme.dart';
import 'package:climasense/core/widgets/grafico_colunas.dart';
import 'package:climasense/models/analise_territorial.dart';
import 'package:climasense/models/clima.dart';
import 'package:climasense/models/ocorrencia.dart';
import 'package:climasense/models/regra_alerta.dart';
import 'suporte/dados_teste.dart';

void main() {
  test(
    'preferências de tema e contraste sobrevivem à reinicialização',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dados = criarDadosTeste();
      await dados.iniciar();
      await dados.alterarTema(ThemeMode.dark);
      await dados.alterarContraste(true);
      final restaurados = criarDadosTeste();
      await restaurados.iniciar();
      expect(restaurados.tema, ThemeMode.dark);
      expect(restaurados.altoContraste, isTrue);
      dados.dispose();
      restaurados.dispose();
    },
  );

  test('sinais meteorológicos exibem evidência e limitações', () {
    final clima = ClimaInfo(20, 80, 0, const [
      PrevisaoDia('2026-11-16', 35, 20),
      PrevisaoDia('2026-11-17', 65, 90),
      PrevisaoDia('2026-11-18', 0, 10),
    ]);
    final alertas = avaliarClima(clima, const Cidade('São Paulo', 0, 0));
    expect(alertas, hasLength(2));
    expect(alertas.first.nivel, 'Atenção');
    expect(alertas.last.nivel, 'Alto');
    expect(alertas.first.evidencia, contains('35.0 mm'));
    expect(
      alertas.first.limitacao,
      contains('sem validação para o seu bairro'),
    );
    expect(avaliarClima(null, null), isEmpty);
  });

  test('série e alertas excluem registros futuros e antigos', () {
    final agora = DateTime.now();
    final registros = [
      Ocorrencia('1', 'Centro', 'Alagamento', 'Observado', agora),
      Ocorrencia(
        '2',
        'Centro',
        'Alagamento',
        'Futuro',
        agora.add(const Duration(days: 1)),
      ),
      Ocorrencia(
        '3',
        'Centro',
        'Alagamento',
        'Antigo',
        agora.subtract(const Duration(days: 8)),
      ),
    ];
    expect(serieOcorrencias(registros, agora).last, 1);
    expect(
      avaliarOcorrencias(registros).single.evidencia,
      startsWith('1 registro'),
    );
    expect(tendenciaRegistros([0, 0, 0, 0, 1, 1, 1]), 'Mais registros');
    expect(tendenciaRegistros([0, 2, 2, 2, 0, 0, 0]), 'Menos registros');
    expect(tendenciaRegistros([0, 0, 0, 0, 0, 0, 0]), 'Estável');
  });

  for (final tamanho in [const Size(360, 800), const Size(1100, 900)]) {
    testWidgets('gráfico vertical acessível em $tamanho e tema escuro', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(tamanho);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: criarTema(Brightness.dark, altoContraste: true),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: GraficoColunas(
                unidade: 'mm',
                dados: [
                  ColunaDado('08/11', 4.4),
                  ColunaDado('09/11', 0),
                  ColunaDado('10/11', null),
                  ColunaDado('11/11', 8.8),
                  ColunaDado('12/11', 6.8),
                  ColunaDado('13/11', 1),
                  ColunaDado('14/11', 0),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('08/11: 4.4 mm'), findsOneWidget);
      expect(find.bySemanticsLabel('10/11: Indisponível'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('navegação, formulário e tema em $tamanho', (tester) async {
      SharedPreferences.setMockInitialValues({'consentimento': true});
      await tester.binding.setSurfaceSize(tamanho);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ClimaSenseApp(dadosApp: criarDadosTeste()));
      await tester.pumpAndSettle();
      expect(find.text('Seus registros da região'), findsOneWidget);
      await tester.tap(find.byTooltip('Escolher tema'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tema escuro'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(find.text('Histórico de ocorrências'), findsOneWidget);
      expect(find.text('Histórico de precipitação'), findsNothing);
      expect(find.textContaining('Dashboard'), findsNothing);
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvar ocorrência'));
      await tester.tap(find.text('Salvar ocorrência'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um bairro válido.'), findsOneWidget);
      expect(
        find.text('Descreva a ocorrência com pelo menos 10 caracteres.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bairro'),
        'Centro',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'Alagamento observado na via.',
      );
      await tester.ensureVisible(find.text('Salvar ocorrência'));
      await tester.tap(find.text('Salvar ocorrência'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ocorrência salva. Consulte Histórico e Alertas.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Alertas'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ocorrências em Centro'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Ocorrências em Centro')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocorrências em Centro'));
      await tester.pumpAndSettle();
      expect(find.text('Sobre este aviso'), findsOneWidget);
      expect(
        find.textContaining('O que observamos: 1 registro'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('consentimento legível com fonte ampliada', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: ClimaSenseApp(dadosApp: criarDadosTeste()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entendi e concordo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
