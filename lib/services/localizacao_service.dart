import 'package:geolocator/geolocator.dart';
import '../models/clima.dart';

class LocalizacaoService {
  Future<Cidade> localizar() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Ative a localização do aparelho e tente novamente.');
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      throw Exception(
        'Localização não autorizada. Você pode buscar a cidade pelo nome.',
      );
    }
    final posicao = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 20),
      ),
    );
    // Arredonda a posição: o painel precisa da região, não do endereço exato.
    final lat = double.parse(posicao.latitude.toStringAsFixed(2));
    final lon = double.parse(posicao.longitude.toStringAsFixed(2));
    return Cidade(
      'Minha região (${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)})',
      lat,
      lon,
    );
  }
}
