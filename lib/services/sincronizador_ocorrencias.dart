import 'banco_ocorrencias.dart';
import 'nuvem_ocorrencias.dart';

class SincronizadorOcorrencias {
  final BancoOcorrencias banco;
  final NuvemOcorrencias nuvem;
  final Duration timeout;
  SincronizadorOcorrencias(
    this.banco,
    this.nuvem, {
    this.timeout = const Duration(seconds: 12),
  });
  Future<void> sincronizar({bool Function()? continuar}) async {
    bool ativo() => continuar?.call() ?? true;
    final uid = await nuvem.conectar().timeout(timeout);
    if (!ativo()) return;
    await banco.vincularUsuario(uid);
    for (final pendencia in await banco.listarPendencias()) {
      if (!ativo()) return;
      if (pendencia.exclusao) {
        await nuvem.excluir(pendencia.id).timeout(timeout);
        if (!ativo()) return;
        await banco.confirmarExclusao(pendencia.id, pendencia.revisao);
      } else {
        await nuvem.enviar(pendencia.ocorrencia!).timeout(timeout);
        if (!ativo()) return;
        // Uma confirmação antiga não pode limpar uma edição feita durante o envio.
        await banco.confirmarEnvio(pendencia.id, revisao: pendencia.revisao);
      }
    }
    if (!ativo()) return;
    final recebidas = await nuvem.listar().timeout(timeout);
    if (ativo()) await banco.incorporar(recebidas, removerAusentes: true);
  }
}
