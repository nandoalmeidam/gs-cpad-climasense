import 'ocorrencia.dart';
import 'clima.dart';

class RegraAlerta {
  final String titulo, evidencia, limitacao, nivel;
  final double confianca;
  const RegraAlerta(
    this.titulo,
    this.evidencia,
    this.limitacao,
    this.nivel,
    this.confianca,
  );
}

List<RegraAlerta> avaliarOcorrencias(List<Ocorrencia> registros) {
  final recentes = registros
      .where(
        (o) =>
            !o.data.isAfter(DateTime.now()) &&
            DateTime.now().difference(o.data) < const Duration(days: 7),
      )
      .toList();
  if (recentes.isEmpty) {
    return [
      const RegraAlerta(
        'Sem registros recentes',
        'Nenhuma ocorrência registrada nos últimos 7 dias neste dispositivo.',
        'Ausência de registros não significa ausência de risco. Não há amostra suficiente.',
        'Informativo',
        0,
      ),
    ];
  }
  final porBairro = <String, int>{};
  for (final o in recentes) {
    porBairro[o.bairro] = (porBairro[o.bairro] ?? 0) + 1;
  }
  return porBairro.entries.map((e) {
    final nivel = e.value >= 5
        ? 'Alto'
        : e.value >= 3
        ? 'Moderado'
        : 'Atenção';
    return RegraAlerta(
      'Ocorrências em ${e.key}',
      '${e.value} ${e.value == 1 ? 'registro' : 'registros'} nos últimos 7 dias.',
      'Os relatos podem estar incompletos ou repetidos. Eles ajudam no acompanhamento, mas não permitem prever um desastre.',
      nivel,
      0,
    );
  }).toList();
}

List<RegraAlerta> avaliarClima(ClimaInfo? clima, Cidade? cidade) {
  if (clima == null || cidade == null) return [];
  return clima.dias
      .where((d) => d.chuva >= 30 || d.vento >= 60)
      .map(
        (d) => RegraAlerta(
          'Previsão em ${cidade.nome} · ${d.data}',
          'Open-Meteo prevê ${d.chuva.toStringAsFixed(1)} mm de precipitação e rajadas de ${d.vento.toStringAsFixed(0)} km/h.',
          'Os limites usados pelo app são referências, sem validação para o seu bairro. A previsão pode mudar e não confirma alagamentos. Confira também os avisos oficiais.',
          d.chuva >= 60 || d.vento >= 90 ? 'Alto' : 'Atenção',
          0,
        ),
      )
      .toList();
}
