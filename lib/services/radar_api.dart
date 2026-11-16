import 'dart:convert';
import 'package:http/http.dart' as http;

class ImagemRadar {
  final DateTime horarioUtc;
  final String urlTemplate;
  const ImagemRadar(this.horarioUtc, this.urlTemplate);
}

class RadarApi {
  final http.Client cliente;
  RadarApi(this.cliente);
  List<ImagemRadar>? _cache;
  DateTime? _consultado;
  Future<List<ImagemRadar>>? _consulta;

  Future<List<ImagemRadar>> consultar({bool atualizar = false}) {
    if (_consulta != null) return _consulta!;
    if (!atualizar &&
        _cache != null &&
        DateTime.now().difference(_consultado!) < const Duration(minutes: 5)) {
      return Future.value(_cache!);
    }
    return _consulta = _carregar()
        .then((imagens) {
          _cache = imagens;
          _consultado = DateTime.now();
          return imagens;
        })
        .whenComplete(() => _consulta = null);
  }

  Future<List<ImagemRadar>> _carregar() async {
    final resposta = await cliente
        .get(Uri.https('api.rainviewer.com', '/public/weather-maps.json'))
        .timeout(const Duration(seconds: 15));
    if (resposta.statusCode != 200) throw Exception('Radar indisponível.');
    final dados =
        jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
    final host = Uri.parse(dados['host'] as String);
    if (host.scheme != 'https' ||
        host.userInfo.isNotEmpty ||
        !(host.host == 'rainviewer.com' ||
            host.host.endsWith('.rainviewer.com'))) {
      throw const FormatException('Servidor de radar inválido.');
    }
    final quadros = dados['radar']?['past'] as List? ?? [];
    final imagens = <int, ImagemRadar>{};
    for (final quadro in quadros) {
      final tempo = quadro['time'];
      final caminho = quadro['path'];
      if (tempo is! int ||
          tempo <= 0 ||
          caminho is! String ||
          !RegExp(r'^/v2/radar/[A-Za-z0-9_-]+$').hasMatch(caminho)) {
        continue;
      }
      imagens[tempo] = ImagemRadar(
        DateTime.fromMillisecondsSinceEpoch(tempo * 1000, isUtc: true),
        '${host.origin}$caminho/256/{z}/{x}/{y}/2/1_0.png',
      );
    }
    final ordenadas = imagens.values.toList()
      ..sort((a, b) => a.horarioUtc.compareTo(b.horarioUtc));
    if (ordenadas.isEmpty) {
      throw Exception('Não há imagens recentes de radar disponíveis.');
    }
    return ordenadas;
  }
}
