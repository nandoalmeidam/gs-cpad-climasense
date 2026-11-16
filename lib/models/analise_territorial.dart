import 'ocorrencia.dart';

/// Série diária para comparar períodos, sem atribuir causalidade aos registros.
List<int> serieOcorrencias(
  List<Ocorrencia> registros,
  DateTime agora, {
  int dias = 7,
}) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  return List.generate(dias, (i) {
    final inicio = hoje.subtract(Duration(days: dias - 1 - i));
    final fim = inicio.add(const Duration(days: 1));
    return registros
        .where(
          (o) =>
              !o.data.isBefore(inicio) &&
              o.data.isBefore(fim) &&
              !o.data.isAfter(agora),
        )
        .length;
  });
}

String tendenciaRegistros(List<int> serie) {
  if (serie.length < 6) return 'Dados insuficientes';
  final ultimos = serie.skip(serie.length - 3).fold<int>(0, (a, b) => a + b);
  final anteriores = serie
      .skip(serie.length - 6)
      .take(3)
      .fold<int>(0, (a, b) => a + b);
  if (ultimos == anteriores) return 'Estável';
  return ultimos > anteriores ? 'Mais registros' : 'Menos registros';
}
