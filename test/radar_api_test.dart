import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:climasense/services/radar_api.dart';
import 'package:climasense/models/clima.dart';
import 'package:climasense/providers/dados_clima.dart';
import 'package:climasense/core/widgets/mapa_clima.dart';

void main() {
  test(
    'usa somente imagens passadas, ordena, elimina duplicatas e cacheia',
    () async {
      var chamadas = 0;
      final api = RadarApi(
        MockClient((r) async {
          chamadas++;
          expect(
            r.url.toString(),
            'https://api.rainviewer.com/public/weather-maps.json',
          );
          return http.Response(
            jsonEncode({
              'host': 'https://tilecache.rainviewer.com',
              'radar': {
                'past': [
                  {'time': 2000, 'path': '/v2/radar/02b2e63eee9a'},
                  {'time': 1000, 'path': '/v2/radar/1000'},
                  {'time': 2000, 'path': '/v2/radar/02b2e63eee9a'},
                ],
                'nowcast': [
                  {'time': 3000, 'path': '/v2/radar/3000'},
                ],
              },
            }),
            200,
          );
        }),
      );
      final imagens = await api.consultar();
      expect(imagens, hasLength(2));
      expect(
        imagens.first.horarioUtc,
        DateTime.fromMillisecondsSinceEpoch(1000000, isUtc: true),
      );
      expect(
        imagens.last.urlTemplate,
        'https://tilecache.rainviewer.com/v2/radar/02b2e63eee9a/256/{z}/{x}/{y}/2/1_0.png',
      );
      await api.consultar();
      expect(chamadas, 1);
      await api.consultar(atualizar: true);
      expect(chamadas, 2);
    },
  );

  test('trata indisponibilidade e permite tentar novamente', () async {
    var chamadas = 0;
    final api = RadarApi(
      MockClient((_) async {
        chamadas++;
        return http.Response('{}', 503);
      }),
    );
    await expectLater(api.consultar(), throwsException);
    await expectLater(api.consultar(), throwsException);
    expect(chamadas, 2);
  });

  test('rejeita servidor inesperado e radar sem dados', () async {
    final hostInvalido = RadarApi(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'host': 'https://outro.example',
            'radar': {'past': []},
          }),
          200,
        ),
      ),
    );
    await expectLater(hostInvalido.consultar(), throwsFormatException);
    final vazio = RadarApi(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'host': 'https://tilecache.rainviewer.com',
            'radar': {'past': []},
          }),
          200,
        ),
      ),
    );
    await expectLater(vazio.consultar(), throwsException);
  });

  testWidgets('radar só consulta quando aberto e permite repetir após falha', (
    tester,
  ) async {
    var chamadas = 0;
    final cliente = MockClient((_) async {
      chamadas++;
      return http.Response('{}', 503);
    });
    final dados = DadosClima()
      ..cidade = const Cidade('São Paulo', -23.55, -46.63);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MapaClima(dados: dados, radar: RadarApi(cliente)),
          ),
        ),
      ),
    );
    expect(chamadas, 0);
    await tester.tap(find.text('Abrir mapa meteorológico'));
    await tester.pumpAndSettle();
    expect(chamadas, 1);
    expect(
      find.textContaining('Não foi possível carregar o radar'),
      findsOneWidget,
    );
    await tester.tap(find.text('Atualizar radar'));
    await tester.pumpAndSettle();
    expect(chamadas, 2);
    expect(tester.takeException(), isNull);
    dados.dispose();
    cliente.close();
  });
}
