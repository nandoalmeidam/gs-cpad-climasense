import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:climasense/models/clima.dart';
import 'package:climasense/services/clima_api.dart';

void main() {
  const cidade = Cidade('Teste', 0, 0);
  test('histórico usa horário da cidade e exclui previsão futura', () async {
    final inicio = DateTime(2026, 1, 1);
    final horas = List.generate(
      216,
      (i) => inicio.add(Duration(hours: i)).toIso8601String().substring(0, 16),
    );
    final api = ClimaApi(
      MockClient((r) async {
        expect(r.url.queryParameters['current'], 'precipitation');
        return http.Response(
          jsonEncode({
            'current': {'time': '2026-01-09T12:30'},
            'hourly': {
              'time': horas,
              'precipitation': List.generate(216, (i) => i > 204 ? 999 : 1),
            },
          }),
          200,
        );
      }),
    );
    final h = await api.consultarHistorico(cidade);
    expect(h.acumuladoHoje, 12);
    expect(h.ultimas24Horas, 24);
    expect(h.ultimos7Dias, 168);
    expect(h.dias.length, 7);
  });
  test('dados ausentes não se tornam chuva zero', () async {
    final inicio = DateTime(2026, 1, 1);
    final api = ClimaApi(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'current': {'time': '2026-01-09T12:30'},
            'hourly': {
              'time': List.generate(
                216,
                (i) => inicio
                    .add(Duration(hours: i))
                    .toIso8601String()
                    .substring(0, 16),
              ),
              'precipitation': List.generate(
                216,
                (i) => i == 200 || i == 50 ? null : 0,
              ),
            },
          }),
          200,
        ),
      ),
    );
    final h = await api.consultarHistorico(cidade);
    expect(h.acumuladoHoje, isNull);
    expect(h.ultimas24Horas, isNull);
    expect(h.ultimos7Dias, isNull);
    expect(h.dias.any((d) => d.milimetros == null), isTrue);
  });
}
