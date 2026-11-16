import 'suporte/dados_teste.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:climasense/app/climasense_app.dart';
import 'package:climasense/core/widgets/grafico_colunas.dart';
import 'package:climasense/models/clima.dart';
import 'package:climasense/models/ocorrencia.dart';
import 'package:climasense/providers/dados_clima.dart';
import 'package:climasense/services/clima_api.dart';
import 'dart:convert';

const gerar = bool.fromEnvironment('CAPTURAR_TELAS');

void main() {
  testWidgets('captura telas reais com dados explicitamente demonstrativos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      final fonte = File(
        Platform.isWindows
            ? '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/segoeui.ttf'
            : '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      );
      if (await fonte.exists()) {
        final carregador = FontLoader('Roboto')
          ..addFont(fonte.readAsBytes().then((b) => ByteData.sublistView(b)));
        await carregador.load();
      }
      final config = File('.dart_tool/package_config.json');
      final pacotes =
          (jsonDecode(await config.readAsString())
                  as Map<String, dynamic>)['packages']
              as List;
      final flutter = pacotes.cast<Map<String, dynamic>>().firstWhere(
        (p) => p['name'] == 'flutter',
      );
      final sdk = Directory.fromUri(
        config.absolute.uri.resolve(flutter['rootUri'] as String),
      ).parent.parent;
      final icones = File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      final carregadorIcones = FontLoader('MaterialIcons')
        ..addFont(icones.readAsBytes().then((b) => ByteData.sublistView(b)));
      await carregadorIcones.load();
    });
    final agora = DateTime.now();
    final demo = DadosClima()
      ..cidade = const Cidade(
        'São Paulo · DADOS DE DEMONSTRAÇÃO',
        -23.55,
        -46.63,
      )
      ..clima = ClimaInfo(
        24,
        78,
        0.3,
        [
          for (var i = 0; i < 3; i++)
            PrevisaoDia(
              agora.add(Duration(days: i)).toIso8601String().substring(0, 10),
              i == 1 ? 65 : 10,
              35,
              minima: 19,
              maxima: 28,
              codigo: 61,
            ),
        ],
        sensacao: 25,
        vento: 12,
        codigo: 61,
        atualizado: '${agora.toIso8601String().substring(0, 10)}T12:00',
      )
      ..historico = HistoricoChuva(
        acumuladoHoje: 2.1,
        ultimas24Horas: 6.2,
        ultimos7Dias: 21.2,
        dias: List.generate(7, (i) {
          final data = agora.subtract(Duration(days: 7 - i));
          return ChuvaDia(
            data: '${data.day}/${data.month}',
            milimetros: [4.4, 0.0, 0.1, 1.1, 8.8, 6.8, 0.0][i],
          );
        }),
      );
    SharedPreferences.setMockInitialValues({
      'consentimento': true,
      'tema': 'light',
      'ocorrencias': jsonEncode(
        List.generate(
          5,
          (i) => Ocorrencia(
            '$i',
            'Bairro de demonstração',
            'Alagamento',
            'Registro sintético para demonstrar a interface.',
            agora.subtract(Duration(hours: i)),
          ).toJson(),
        ),
      ),
    });
    final chave = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: chave,
        child: ClimaSenseApp(dadosClima: demo, dadosApp: criarDadosTeste()),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capturar(String nome) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            chave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final imagem = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
        final arquivo = File('assets/screenshots/$nome.png');
        await arquivo.parent.create(recursive: true);
        await arquivo.writeAsBytes(bytes!.buffer.asUint8List());
        imagem.dispose();
      });
    }

    await capturar('inicio');
    await tester.tap(find.text('Clima'));
    await tester.pumpAndSettle();
    // O cartão deve herdar a fonte do tema, inclusive na captura de widget.
    expect(
      DefaultTextStyle.of(tester.element(find.text('24°'))).style.fontFamily,
      'Roboto',
    );
    await capturar('clima');
    await tester.scrollUntilVisible(
      find.byType(GraficoColunas),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await capturar('chuvas');
    await tester.tap(find.text('Alertas'));
    await tester.pumpAndSettle();
    await capturar('alertas');
    await tester.scrollUntilVisible(
      find.text('Ocorrências em Bairro de demonstração'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Ocorrências em Bairro de demonstração')),
      alignment: 0.3,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocorrências em Bairro de demonstração'));
    await tester.pumpAndSettle();
    await capturar('detalhe_alerta');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    await capturar('historico');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ocorrencia_0')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Opções da ocorrência').first);
    await tester.pumpAndSettle();
    await capturar('opcoes_ocorrencia');
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await capturar('edicao');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Criar conta ou entrar'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Criar conta ou entrar'));
    await tester.pumpAndSettle();
    await capturar('conta');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    await capturar('cadastro');
    await tester.tap(find.byTooltip('Escolher tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tema escuro'));
    await tester.pumpAndSettle();
    await capturar('escuro');
    await tester.tap(find.byTooltip('Alto contraste'));
    await tester.pumpAndSettle();
    await capturar('alto_contraste');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      RepaintBoundary(
        key: chave,
        child: ClimaSenseApp(dadosApp: criarDadosTeste()),
      ),
    );
    await tester.pumpAndSettle();
    await capturar('consentimento');
    expect(tester.takeException(), isNull);
  }, skip: !gerar);
}
