import 'package:sembast/sembast.dart';
import '../models/ocorrencia.dart';

class PendenciaOcorrencia {
  final String id;
  final int revisao;
  final Ocorrencia? ocorrencia;
  bool get exclusao => ocorrencia == null;
  const PendenciaOcorrencia(this.id, this.revisao, this.ocorrencia);
}

class BancoOcorrencias {
  final Database database;
  BancoOcorrencias(this.database);
  // A área vazia mantém o banco das versões anteriores; cada conta tem a sua.
  String _area = '';
  final _sessao = StoreRef<String, Object?>('sessao');
  StoreRef<String, Map<String, Object?>> get _registros =>
      stringMapStoreFactory.store('ocorrencias$_area');
  StoreRef<String, Map<String, Object?>> get _exclusoes =>
      stringMapStoreFactory.store('exclusoes_pendentes$_area');
  StoreRef<String, Object?> get _meta =>
      StoreRef<String, Object?>('metadados$_area');
  Future<void> preparar() async {
    _area = (await _sessao.record('area').get(database) as String?) ?? '';
  }

  Future<void> selecionarConta(
    String usuario, {
    required bool preservar,
    bool visitante = false,
  }) async {
    final escolhida = await database.transaction((tx) async {
      final anterior = await _meta.record('usuario_nuvem').get(tx);
      if (anterior == usuario || preservar) {
        if (preservar && anterior != null && anterior != usuario) {
          // Vinculação explícita de um visitante a uma nova conta por e-mail.
          for (final registro in await _registros.find(tx)) {
            await _registros.record(registro.key).update(tx, {
              'pendente': true,
            });
          }
        }
        await _meta.record('usuario_nuvem').put(tx, usuario);
        await _meta.record('conta_email').put(tx, true);
        if (await _sessao.record('visitante').get(tx) == _area) {
          await _sessao.record('visitante').delete(tx);
        }
        await _sessao.record('conta_$usuario').put(tx, _area);
        return _area;
      }
      if (anterior == null || visitante) {
        await _sessao.record('visitante').put(tx, _area);
      }
      final area =
          (await _sessao.record('conta_$usuario').get(tx) as String?) ??
          '_${Uri.encodeComponent(usuario)}';
      final meta = StoreRef<String, Object?>('metadados$area');
      final dono = await meta.record('usuario_nuvem').get(tx);
      if (dono != null && dono != usuario) {
        throw StateError('Área de outra conta.');
      }
      // Seleção e migração são atômicas: uma interrupção não importa dados
      // antigos de SharedPreferences para a conta recém-selecionada.
      await meta.record('migrado_preferences').put(tx, true);
      await meta.record('usuario_nuvem').put(tx, usuario);
      await meta.record('conta_email').put(tx, true);
      await _sessao.record('conta_$usuario').put(tx, area);
      await _sessao.record('area').put(tx, area);
      return area;
    });
    _area = escolhida;
  }

  Future<void> selecionarVisitante() async {
    var area =
        (await _sessao.record('visitante').get(database) as String?) ??
        '_visitante_${DateTime.now().microsecondsSinceEpoch}';
    await database.transaction((tx) async {
      if (await StoreRef<String, Object?>(
            'metadados$area',
          ).record('conta_email').get(tx) ==
          true) {
        area = '_visitante_${DateTime.now().microsecondsSinceEpoch}';
        await _sessao.record('visitante').delete(tx);
      }
      await StoreRef<String, Object?>(
        'metadados$area',
      ).record('migrado_preferences').put(tx, true);
      await _sessao.record('area').put(tx, area);
    });
    _area = area;
  }

  Future<bool> get precisaMigrar async =>
      await _meta.record('migrado_preferences').get(database) != true;

  Future<void> migrar(List<Ocorrencia> antigos) =>
      database.transaction((tx) async {
        if (await _meta.record('migrado_preferences').get(tx) == true) return;
        for (final item in antigos) {
          if (!await _registros.record(item.id).exists(tx)) {
            await _registros.record(item.id).put(tx, {
              ...item.toJson(),
              'pendente': true,
              'revisao': 1,
            });
          }
        }
        await _meta.record('migrado_preferences').put(tx, true);
      });

  Future<void> adicionar(Ocorrencia item) => _gravar(item, editar: false);
  Future<void> editar(Ocorrencia item) => _gravar(item, editar: true);
  Future<void> _gravar(Ocorrencia item, {required bool editar}) =>
      database.transaction((tx) async {
        final atual = await _registros.record(item.id).get(tx);
        if (editar && atual == null) {
          throw StateError('Esta ocorrência já foi excluída.');
        }
        if (!editar &&
            (atual != null || await _exclusoes.record(item.id).exists(tx))) {
          throw StateError('Já existe uma ocorrência com este identificador.');
        }
        if (editar && atual!['data'] != item.toJson()['data']) {
          throw StateError('A data original do registro deve ser mantida.');
        }
        await _registros.record(item.id).put(tx, {
          ...item.toJson(),
          'pendente': true,
          'revisao': ((atual?['revisao'] as int?) ?? 0) + 1,
        });
      });

  Future<void> excluir(String id) => database.transaction((tx) async {
    final atual = await _registros.record(id).get(tx);
    if (atual == null) return;
    await _exclusoes.record(id).put(tx, {
      'revisao': ((atual['revisao'] as int?) ?? 0) + 1,
      'pendente': true,
    });
    await _registros.record(id).delete(tx);
  });

  Future<List<Ocorrencia>> listar({bool somentePendentes = false}) async {
    final registros = await _registros.find(
      database,
      finder: somentePendentes
          ? Finder(filter: Filter.equals('pendente', true))
          : null,
    );
    return registros.map((r) => Ocorrencia.fromJson(r.value)).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
  }

  Future<List<PendenciaOcorrencia>> listarPendencias() => database.transaction((
    tx,
  ) async {
    final registros = await _registros.find(
      tx,
      finder: Finder(filter: Filter.equals('pendente', true)),
    );
    final exclusoes = await _exclusoes.find(
      tx,
      finder: Finder(filter: Filter.equals('pendente', true)),
    );
    return [
      ...registros.map(
        (r) => PendenciaOcorrencia(
          r.key,
          (r.value['revisao'] as int?) ?? 0,
          Ocorrencia.fromJson(r.value),
        ),
      ),
      ...exclusoes.map(
        (r) =>
            PendenciaOcorrencia(r.key, (r.value['revisao'] as int?) ?? 0, null),
      ),
    ];
  });

  Future<void> confirmarEnvio(String id, {int? revisao}) =>
      database.transaction((tx) async {
        final atual = await _registros.record(id).get(tx);
        if (atual == null ||
            (revisao != null && ((atual['revisao'] as int?) ?? 0) != revisao)) {
          return;
        }
        await _registros.record(id).update(tx, {'pendente': false});
      });
  Future<void> confirmarExclusao(String id, int revisao) =>
      database.transaction((tx) async {
        final atual = await _exclusoes.record(id).get(tx);
        if (atual?['revisao'] == revisao) {
          await _exclusoes.record(id).update(tx, {'pendente': false});
        }
      });

  Future<void> incorporar(
    List<Ocorrencia> recebidas, {
    bool removerAusentes = false,
  }) => database.transaction((tx) async {
    for (final item in recebidas) {
      final exclusao = await _exclusoes.record(item.id).get(tx);
      if (exclusao != null) {
        // Ignora respostas antigas e agenda a remoção de uma cópia reaparecida.
        if (exclusao['pendente'] != true) {
          await _exclusoes.record(item.id).update(tx, {'pendente': true});
        }
        continue;
      }
      final atual = await _registros.record(item.id).get(tx);
      if (atual?['pendente'] == true) continue;
      await _registros.record(item.id).put(tx, {
        ...item.toJson(),
        'pendente': false,
        'revisao': atual?['revisao'] ?? 0,
      });
    }
    if (removerAusentes) {
      final ids = recebidas.map((item) => item.id).toSet();
      for (final registro in await _registros.find(tx)) {
        if (registro.value['pendente'] == true || ids.contains(registro.key)) {
          continue;
        }
        // Snapshot completo confirmado pelo servidor: a ausência indica que
        // outro aparelho (ou o dono no Console) excluiu o registro.
        await _exclusoes.record(registro.key).put(tx, {
          'revisao': ((registro.value['revisao'] as int?) ?? 0) + 1,
          'pendente': false,
        });
        await _registros.record(registro.key).delete(tx);
      }
    }
  });

  Future<void> vincularUsuario(String uid) => database.transaction((tx) async {
    final anterior = await _meta.record('usuario_nuvem').get(tx);
    if (anterior != null && anterior != uid) {
      throw StateError(
        'A conta conectada mudou. Os registros locais não foram enviados para outra conta.',
      );
    }
    await _meta.record('usuario_nuvem').put(tx, uid);
  });
  Future<void> fechar() => database.close();
}
