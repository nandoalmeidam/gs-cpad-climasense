import '../models/ocorrencia.dart';

abstract interface class NuvemOcorrencias {
  bool get configurada;
  Future<String> conectar();
  Future<void> enviar(Ocorrencia item);
  Future<void> excluir(String id);
  Future<List<Ocorrencia>> listar();
}
