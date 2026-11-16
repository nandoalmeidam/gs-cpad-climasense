import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/clima.dart';
import 'sugestao_cidades_service.dart';

class ChuvaDia {
  final String data;
  final double? milimetros;
  const ChuvaDia({required this.data, required this.milimetros});
}

class HistoricoChuva {
  final double? acumuladoHoje, ultimas24Horas, ultimos7Dias;
  final List<ChuvaDia> dias;
  const HistoricoChuva({
    required this.acumuladoHoje,
    required this.ultimas24Horas,
    required this.ultimos7Dias,
    required this.dias,
  });
}

class ClimaApi {
  final http.Client cliente;
  ClimaApi(this.cliente) : sugestoes = SugestaoCidadesService(cliente);
  final SugestaoCidadesService sugestoes;
  Future<Map<String, dynamic>> _get(
    String host,
    String path,
    Map<String, String> params,
  ) async {
    final r = await cliente
        .get(Uri.https(host, path, params))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('Serviço indisponível');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<Cidade>> _buscarExato(String termo, {String? estado}) async {
    if (termo.trim().length < 2) return [];
    final dados = await _get('geocoding-api.open-meteo.com', '/v1/search', {
      'name': termo.trim(),
      'count': '20',
      'language': 'pt',
      'format': 'json',
    });
    final itens = List<Map<String, dynamic>>.from(dados['results'] ?? []);
    itens.sort(
      (a, b) => (b['country_code'] == 'BR' ? 1 : 0).compareTo(
        a['country_code'] == 'BR' ? 1 : 0,
      ),
    );
    return itens
        .where(
          (c) =>
              estado == null ||
              (c['country_code'] == 'BR' &&
                  sugestoes.normalizar(c['admin1'] as String? ?? '') ==
                      sugestoes.normalizar(estado)),
        )
        .map(
          (c) => Cidade(
            '${c['name']} — ${c['admin1'] ?? c['country']}, ${c['country']}',
            (c['latitude'] as num).toDouble(),
            (c['longitude'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<Cidade>> buscar(String termo) async {
    if (termo.trim().length < 2) return [];
    final exatas = await _buscarExato(termo);
    if (exatas.isNotEmpty) return exatas;
    final proximas = await sugestoes.sugerir(termo);
    // Resolve as coordenadas pelo nome correto e pelo estado do IBGE.
    // Uma falha isolada não impede que as outras sugestões apareçam.
    final resultados = await Future.wait(
      proximas.take(5).map((cidade) async {
        try {
          return await _buscarExato(cidade.nome, estado: cidade.estadoNome);
        } catch (_) {
          return <Cidade>[];
        }
      }),
    );
    final unicas = <String, Cidade>{};
    for (final lista in resultados) {
      for (final cidade in lista) {
        unicas['${cidade.latitude},${cidade.longitude}'] = cidade;
      }
    }
    return unicas.values.toList();
  }

  Map<String, String> _local(Cidade c) => {
    'latitude': '${c.latitude}',
    'longitude': '${c.longitude}',
    'timezone': 'auto',
  };
  Future<ClimaInfo> consultar(Cidade cidade) async {
    final d = await _get('api.open-meteo.com', '/v1/forecast', {
      ..._local(cidade),
      'current':
          'temperature_2m,relative_humidity_2m,precipitation,apparent_temperature,weather_code,wind_speed_10m',
      'daily':
          'precipitation_sum,wind_gusts_10m_max,temperature_2m_min,temperature_2m_max,weather_code',
      'forecast_days': '3',
    });
    final a = d['current'];
    final diario = d['daily'];
    double numero(dynamic v) => (v as num).toDouble();
    return ClimaInfo(
      numero(a['temperature_2m']),
      numero(a['relative_humidity_2m']),
      numero(a['precipitation']),
      List.generate(
        (diario['time'] as List).length,
        (i) => PrevisaoDia(
          diario['time'][i],
          numero(diario['precipitation_sum'][i]),
          numero(diario['wind_gusts_10m_max'][i]),
          minima: numero(diario['temperature_2m_min'][i]),
          maxima: numero(diario['temperature_2m_max'][i]),
          codigo: diario['weather_code'][i] as int,
        ),
      ),
      sensacao: numero(a['apparent_temperature']),
      vento: numero(a['wind_speed_10m']),
      codigo: a['weather_code'] as int,
      atualizado: a['time'] as String,
    );
  }

  Future<HistoricoChuva> consultarHistorico(Cidade cidade) async {
    final d = await _get('api.open-meteo.com', '/v1/forecast', {
      ..._local(cidade),
      'current': 'precipitation',
      'hourly': 'precipitation',
      'past_days': '7',
      'forecast_days': '1',
    });
    // Os horários são locais da cidade consultada, inclusive a referência atual.
    final agora = DateTime.parse(d['current']['time'] as String);
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final tempos = d['hourly']['time'] as List;
    final valores = d['hourly']['precipitation'] as List;
    final amostras = <DateTime, double>{};
    for (var i = 0; i < tempos.length; i++) {
      final hora = DateTime.parse(tempos[i] as String);
      if (!hora.isAfter(agora) && valores[i] != null) {
        amostras[hora] = (valores[i] as num).toDouble();
      }
    }
    // Precipitação horária corresponde à hora anterior ao horário indicado.
    double? somar(DateTime inicio, DateTime fim, int esperado) {
      final itens = amostras.entries
          .where((e) => e.key.isAfter(inicio) && !e.key.isAfter(fim))
          .toList();
      if (itens.length != esperado) return null;
      return itens.fold<double>(0, (s, e) => s + e.value);
    }

    final horaAtual = DateTime(agora.year, agora.month, agora.day, agora.hour);
    final dias = List.generate(7, (i) {
      final inicio = hoje.subtract(Duration(days: 7 - i));
      return ChuvaDia(
        data:
            '${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')}',
        milimetros: somar(inicio, inicio.add(const Duration(days: 1)), 24),
      );
    });
    return HistoricoChuva(
      acumuladoHoje: somar(hoje, horaAtual, agora.hour),
      ultimas24Horas: somar(
        horaAtual.subtract(const Duration(hours: 24)),
        horaAtual,
        24,
      ),
      ultimos7Dias: dias.every((d) => d.milimetros != null)
          ? dias.fold<double>(0, (s, d) => s + d.milimetros!)
          : null,
      dias: dias,
    );
  }
}
