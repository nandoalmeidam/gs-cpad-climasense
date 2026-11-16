import 'package:sembast/sembast_memory.dart';
import 'package:climasense/providers/dados_app.dart';
import 'package:climasense/services/banco_ocorrencias.dart';

DadosApp criarDadosTeste() => DadosApp(
  abrirBanco: () async => BancoOcorrencias(
    await newDatabaseFactoryMemory().openDatabase('climasense-teste'),
  ),
);
