import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../models/ocorrencia.dart';
import 'nuvem_ocorrencias.dart';
import 'conta_service.dart';

class FirebaseOcorrencias implements NuvemOcorrencias, ContaService {
  FirebaseAuth? get _auth =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance;
  @override
  String? get email => _auth?.currentUser?.email;
  @override
  bool get contaPermanente => _auth?.currentUser?.isAnonymous == false;
  @override
  Future<String> criarConta(String email, String senha) async {
    await conectar();
    final usuario = _auth!.currentUser!;
    if (!usuario.isAnonymous) {
      throw StateError('Você já está conectado a uma conta.');
    }
    await usuario.linkWithCredential(
      EmailAuthProvider.credential(email: email.trim(), password: senha),
    );
    return conectar();
  }

  @override
  Future<String> entrar(String email, String senha) async {
    await conectar();
    await _auth!.signInWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
    return conectar();
  }

  @override
  Future<void> recuperarSenha(String email) async {
    await conectar();
    await _auth!.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> sair() async {
    await _auth?.signOut();
    _uid = null;
    _firestore = null;
  }

  FirebaseFirestore? _firestore;
  String? _uid;
  FirebaseOptions? _opcoes() {
    try {
      return DefaultFirebaseOptions.currentPlatform;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get configurada => _opcoes() != null;

  @override
  Future<String> conectar() async {
    final options = _opcoes();
    if (options == null) {
      throw StateError('A cópia na nuvem ainda não foi configurada.');
    }
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    if (Firebase.app().options.projectId != options.projectId) {
      throw StateError(
        'A conexão mudou. Reinicie o aplicativo antes de sincronizar.',
      );
    }
    final auth = FirebaseAuth.instance;
    final usuario = auth.currentUser ?? (await auth.signInAnonymously()).user;
    if (usuario == null) throw StateError('Não foi possível conectar à conta.');
    _uid = usuario.uid;
    _firestore = FirebaseFirestore.instance;
    return '${options.projectId}/$_uid';
  }

  CollectionReference<Map<String, dynamic>> get _colecao {
    if (_uid == null || _firestore == null) {
      throw StateError('Conexão não iniciada.');
    }
    return _firestore!
        .collection('usuarios')
        .doc(_uid)
        .collection('ocorrencias');
  }

  @override
  Future<void> enviar(Ocorrencia item) async {
    final referencia = _colecao.doc(item.id);
    final esperado = item.toJson();
    // Transações exigem conexão: a fila offline é a do banco local, não uma
    // segunda fila de escritas do SDK que cresceria a cada timeout.
    await _firestore!.runTransaction<void>(
      (tx) async {
        final existente = await tx.get(referencia);
        if (existente.exists) {
          final dados = existente.data()!;
          if (dados['id'] != item.id || dados['data'] != esperado['data']) {
            throw StateError(
              'O identificador ou a data original da ocorrência não correspondem à cópia na nuvem.',
            );
          }
          if (esperado.entries.every((e) => dados[e.key] == e.value)) return;
        }
        tx.set(referencia, {
          ...esperado,
          'sincronizadoEm': FieldValue.serverTimestamp(),
        });
      },
      timeout: const Duration(seconds: 10),
      maxAttempts: 2,
    );
  }

  @override
  Future<void> excluir(String id) async {
    final referencia = _colecao.doc(id);
    await _firestore!.runTransaction<void>(
      (tx) async {
        final existente = await tx.get(referencia);
        if (existente.exists) tx.delete(referencia);
      },
      timeout: const Duration(seconds: 10),
      maxAttempts: 2,
    );
  }

  @override
  Future<List<Ocorrencia>> listar() async {
    // A confirmação de sincronização deve vir do servidor, não do cache do SDK.
    final resultado = await _colecao.get(
      const GetOptions(source: Source.server),
    );
    return resultado.docs
        .map((doc) => Ocorrencia.fromJson(doc.data()))
        .toList();
  }
}
