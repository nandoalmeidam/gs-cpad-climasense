import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'banco_ocorrencias.dart';

Future<BancoOcorrencias> abrirBancoOcorrencias() async {
  final pasta = await getApplicationDocumentsDirectory();
  final database = await databaseFactoryIo.openDatabase(
    path.join(pasta.path, 'climasense.db'),
  );
  return BancoOcorrencias(database);
}
