import 'package:sembast_web/sembast_web.dart';
import 'banco_ocorrencias.dart';

Future<BancoOcorrencias> abrirBancoOcorrencias() async =>
    BancoOcorrencias(await databaseFactoryWeb.openDatabase('climasense'));
