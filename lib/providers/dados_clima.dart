import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clima.dart';
import '../services/clima_api.dart';

class DadosClima extends ChangeNotifier {
  final ClimaApi api;
  DadosClima({ClimaApi? api}) : api = api ?? ClimaApi(http.Client());
  Cidade? cidade;
  ClimaInfo? clima;
  HistoricoChuva? historico;
  bool carregando = false;
  String? erro, erroHistorico;
  int _versao = 0;
  bool _encerrado = false;

  Future<void> iniciar() async {
    final prefs = await SharedPreferences.getInstance();
    if (_encerrado) return;
    final nome = prefs.getString('cidade_nome');
    if (nome != null &&
        prefs.getDouble('cidade_lat') != null &&
        prefs.getDouble('cidade_lon') != null) {
      await selecionar(
        Cidade(
          nome,
          prefs.getDouble('cidade_lat')!,
          prefs.getDouble('cidade_lon')!,
        ),
      );
    }
  }

  Future<void> selecionar(Cidade local) async {
    final versao = ++_versao;
    cidade = local;
    clima = null;
    historico = null;
    erro = null;
    erroHistorico = null;
    carregando = true;
    notifyListeners();
    await Future.wait([
      () async {
        try {
          final resultado = await api.consultar(local);
          if (!_encerrado && versao == _versao) clima = resultado;
        } catch (_) {
          if (!_encerrado && versao == _versao) {
            erro =
                'Não foi possível carregar o clima. Verifique a conexão e tente atualizar.';
          }
        }
      }(),
      () async {
        try {
          final resultado = await api.consultarHistorico(local);
          if (!_encerrado && versao == _versao) historico = resultado;
        } catch (_) {
          if (!_encerrado && versao == _versao) {
            erroHistorico = 'Histórico de chuva indisponível. Tente atualizar.';
          }
        }
      }(),
    ]);
    if (_encerrado || versao != _versao) return;
    carregando = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_encerrado || versao != _versao) return;
    await prefs.setString('cidade_nome', local.nome);
    await prefs.setDouble('cidade_lat', local.latitude);
    await prefs.setDouble('cidade_lon', local.longitude);
  }

  @override
  void dispose() {
    _encerrado = true;
    api.cliente.close();
    super.dispose();
  }
}
