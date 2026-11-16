import 'package:flutter_test/flutter_test.dart';
import 'package:climasense/models/ocorrencia.dart';
import 'package:climasense/models/regra_alerta.dart';

void main() {
  test('regras sem registros deixam limitações claras', () {
    final alertas = avaliarOcorrencias([]);
    expect(alertas, hasLength(1));
    expect(alertas.first.nivel, 'Informativo');
    expect(alertas.first.limitacao, contains('amostra'));
  });
  test('regras identificam concentração de registros', () {
    final hoje = DateTime.now();
    final registros = List.generate(
      5,
      (i) => Ocorrencia('$i', 'Centro', 'Alagamento', 'Chuva forte', hoje),
    );
    final alerta = avaliarOcorrencias(registros).single;
    expect(alerta.nivel, 'Alto');
    expect(alerta.evidencia, contains('5 registro'));
  });
}
