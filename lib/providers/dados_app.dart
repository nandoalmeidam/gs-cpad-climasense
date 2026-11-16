import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ocorrencia.dart';
import '../models/regra_alerta.dart';
import '../services/notificacoes_service.dart';
import '../services/abrir_banco.dart';
import '../services/banco_ocorrencias.dart';
import '../services/firebase_ocorrencias.dart';
import '../services/nuvem_ocorrencias.dart';
import '../services/conta_service.dart';
import '../services/sincronizador_ocorrencias.dart';

class DadosApp extends ChangeNotifier {
  final Future<BancoOcorrencias> Function() abrirBanco;
  final NuvemOcorrencias nuvem;
  final Duration intervaloSincronizacao;
  DadosApp({
    Future<BancoOcorrencias> Function()? abrirBanco,
    NuvemOcorrencias? nuvem,
    NotificacoesService? avisos,
    this.intervaloSincronizacao = const Duration(minutes: 1),
  }) : abrirBanco = abrirBanco ?? abrirBancoOcorrencias,
       nuvem = nuvem ?? FirebaseOcorrencias(),
       avisos = avisos ?? NotificacoesService();

  List<Ocorrencia> ocorrencias = [];
  bool consentiu = false, pronto = false;
  ThemeMode tema = ThemeMode.system;
  bool altoContraste = false, notificacoes = false;
  String? erroNotificacao, erroInicializacao, erroNuvem;
  final NotificacoesService avisos;
  BancoOcorrencias? _banco;
  Future<void>? _inicio;
  Future<void> _gravacoes = Future.value();
  Timer? _timer;
  bool _encerrado = false, _repetirSync = false;
  bool nuvemAtiva = false, sincronizando = false;
  int pendentes = 0;
  DateTime? ultimaSincronizacao;
  bool get nuvemConfigurada => nuvem.configurada;
  ContaService? get conta =>
      nuvem is ContaService ? nuvem as ContaService : null;
  bool alterandoConta = false;
  Future<void>? _syncAtual;

  Future<void> acessarConta({
    required String email,
    required String senha,
    required bool criar,
  }) async {
    if (alterandoConta) throw StateError('Aguarde a operação atual.');
    await iniciar();
    if (!pronto || conta == null) throw StateError('Conta indisponível.');
    alterandoConta = true;
    _repetirSync = false;
    _avisar();
    try {
      // Termina o envio atual antes de substituir a identidade usada pelo SDK.
      await _syncAtual;
      await _gravacoes;
      final visitante = !conta!.contaPermanente;
      final uid = criar
          ? await conta!.criarConta(email, senha)
          : await conta!.entrar(email, senha);
      await _banco!.selecionarConta(
        uid,
        preservar: criar,
        visitante: visitante,
      );
      ultimaSincronizacao = null;
      await _atualizarRegistros();
      await (await SharedPreferences.getInstance()).remove(
        'ultima_sincronizacao',
      );
      await configurarNuvem(true);
    } finally {
      alterandoConta = false;
      _avisar();
    }
    await sincronizar();
  }

  Future<void> sairDaConta() async {
    if (alterandoConta) return;
    alterandoConta = true;
    _repetirSync = false;
    _avisar();
    try {
      await _syncAtual;
      await _gravacoes;
      if (pendentes > 0) {
        throw StateError('Sincronize as alterações pendentes antes de sair.');
      }
      await conta?.sair();
      await _banco!.selecionarVisitante();
      await configurarNuvem(false);
      ultimaSincronizacao = null;
      await (await SharedPreferences.getInstance()).remove(
        'ultima_sincronizacao',
      );
      await _atualizarRegistros();
    } finally {
      alterandoConta = false;
      _avisar();
    }
  }

  void _avisar() {
    if (!_encerrado) notifyListeners();
  }

  Future<void> iniciar() => _inicio ??= _iniciar();

  Future<void> _iniciar() async {
    erroInicializacao = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      consentiu = prefs.getBool('consentimento') ?? false;
      altoContraste = prefs.getBool('alto_contraste') ?? false;
      notificacoes = prefs.getBool('notificacoes') ?? false;
      nuvemAtiva = prefs.getBool('copia_nuvem') ?? false;
      ultimaSincronizacao = DateTime.tryParse(
        prefs.getString('ultima_sincronizacao') ?? '',
      );
      tema = ThemeMode.values.firstWhere(
        (t) => t.name == prefs.getString('tema'),
        orElse: () => ThemeMode.system,
      );
      final banco = await abrirBanco();
      if (_encerrado) {
        await banco.fechar();
        return;
      }
      _banco = banco;
      await banco.preparar();
      if (await banco.precisaMigrar) {
        final antigos =
            (jsonDecode(prefs.getString('ocorrencias') ?? '[]') as List)
                .map(
                  (e) =>
                      Ocorrencia.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
        await banco.migrar(antigos);
      }
      await _atualizarRegistros();
      if (_encerrado) return;
      pronto = true;
      _programarSincronizacao();
      if (consentiu && notificacoes) {
        unawaited(verificarNotificacoes(avaliarOcorrencias(ocorrencias)));
      }
      if (consentiu && nuvemAtiva) unawaited(sincronizar());
    } catch (_) {
      erroInicializacao =
          'Não foi possível abrir seus registros. Tente novamente.';
      if (_banco != null) {
        try {
          await _banco!.fechar();
        } catch (_) {
          /* Mantém a mensagem de falha de abertura. */
        }
      }
      _banco = null;
      _inicio = null;
    }
    _avisar();
  }

  Future<void> _atualizarRegistros() async {
    final banco = _banco!;
    final registros = await banco.listar();
    final aguardando = await banco.listarPendencias();
    if (_encerrado) return;
    ocorrencias = registros;
    pendentes = aguardando.length;
  }

  Future<void> alterarTema(ThemeMode valor) async {
    await (await SharedPreferences.getInstance()).setString('tema', valor.name);
    tema = valor;
    _avisar();
  }

  Future<void> alterarContraste(bool valor) async {
    await (await SharedPreferences.getInstance()).setBool(
      'alto_contraste',
      valor,
    );
    altoContraste = valor;
    _avisar();
  }

  Future<void> consentir() async {
    final salvo = await (await SharedPreferences.getInstance()).setBool(
      'consentimento',
      true,
    );
    if (!salvo) throw Exception('Não foi possível salvar o consentimento.');
    consentiu = true;
    _avisar();
    _programarSincronizacao();
    if (nuvemAtiva) unawaited(sincronizar());
  }

  Future<void> configurarNuvem(bool ativar) async {
    if (ativar && !nuvemConfigurada) {
      throw StateError('A cópia na nuvem ainda não está disponível.');
    }
    final salvo = await (await SharedPreferences.getInstance()).setBool(
      'copia_nuvem',
      ativar,
    );
    if (!salvo) throw Exception('Não foi possível salvar essa preferência.');
    nuvemAtiva = ativar;
    erroNuvem = null;
    _programarSincronizacao();
    _avisar();
    if (ativar) unawaited(sincronizar());
  }

  void _programarSincronizacao() {
    _timer?.cancel();
    if (!_encerrado &&
        consentiu &&
        nuvemAtiva &&
        nuvemConfigurada &&
        intervaloSincronizacao > Duration.zero) {
      _timer = Timer.periodic(
        intervaloSincronizacao,
        (_) => unawaited(sincronizar()),
      );
    }
  }

  Future<void> sincronizar() {
    if (alterandoConta) return Future.value();
    if (_syncAtual != null) {
      _repetirSync = true;
      return _syncAtual!;
    }
    return _syncAtual = _sincronizar().whenComplete(() {
      _syncAtual = null;
      if (!_encerrado && nuvemAtiva && !alterandoConta && _repetirSync) {
        _repetirSync = false;
        unawaited(sincronizar());
      }
    });
  }

  Future<void> _sincronizar() async {
    await iniciar();
    if (_encerrado ||
        !pronto ||
        !consentiu ||
        !nuvemAtiva ||
        !nuvemConfigurada) {
      return;
    }
    if (sincronizando) {
      _repetirSync = true;
      return;
    }
    sincronizando = true;
    erroNuvem = null;
    _repetirSync = false;
    _avisar();
    try {
      await SincronizadorOcorrencias(_banco!, nuvem).sincronizar(
        continuar: () => !_encerrado && nuvemAtiva && !alterandoConta,
      );
      if (_encerrado) return;
      await _atualizarRegistros();
      if (nuvemAtiva) {
        ultimaSincronizacao = DateTime.now();
        await (await SharedPreferences.getInstance()).setString(
          'ultima_sincronizacao',
          ultimaSincronizacao!.toIso8601String(),
        );
      }
    } catch (e) {
      if (_encerrado) return;
      erroNuvem = e is StateError
          ? e.message
          : 'Não foi possível sincronizar agora. Seus registros continuam salvos neste aparelho.';
      try {
        await _atualizarRegistros();
      } catch (_) {
        // Uma falha local de leitura não deve gerar uma exceção de rede solta.
      }
    } finally {
      sincronizando = false;
      _avisar();
    }
  }

  Future<bool> configurarNotificacoes(bool valor) async {
    final permitido = !valor || await avisos.ativar();
    notificacoes = valor && permitido;
    await (await SharedPreferences.getInstance()).setBool(
      'notificacoes',
      notificacoes,
    );
    _avisar();
    return permitido;
  }

  Future<void> verificarNotificacoes(List<RegraAlerta> alertas) async {
    try {
      await avisos.verificar(alertas);
      erroNotificacao = null;
    } catch (erro) {
      erroNotificacao = erro is PermissaoNotificacaoException
          ? erro.toString()
          : 'Não foi possível enviar a notificação. O aviso continua disponível em Alertas.';
    }
    _avisar();
  }

  Future<void> adicionar(Ocorrencia item) =>
      _alterarBanco((banco) => banco.adicionar(item));
  Future<void> editar(Ocorrencia item) =>
      _alterarBanco((banco) => banco.editar(item));
  Future<void> excluir(String id) =>
      _alterarBanco((banco) => banco.excluir(id));

  Future<void> _alterarBanco(Future<void> Function(BancoOcorrencias) alterar) {
    if (alterandoConta) {
      return Future.error(StateError('Aguarde a troca de conta.'));
    }
    final operacao = _gravacoes.then((_) async {
      await iniciar();
      if (!pronto || _banco == null) {
        throw StateError('O banco local não está disponível.');
      }
      await alterar(_banco!);
      await _atualizarRegistros();
      _avisar();
      // A confirmação do formulário depende só da gravação local.
      // A rede não pode impedir que uma ocorrência seja registrada offline.
      unawaited(sincronizar());
      unawaited(verificarNotificacoes(avaliarOcorrencias(ocorrencias)));
    });
    _gravacoes = operacao.catchError((Object _) {});
    return operacao;
  }

  int contar(String tipo) => ocorrencias.where((o) => o.tipo == tipo).length;
  Map<String, int> porBairro() {
    final mapa = <String, int>{};
    for (final o in ocorrencias) {
      mapa[o.bairro] = (mapa[o.bairro] ?? 0) + 1;
    }
    return mapa;
  }

  @override
  void dispose() {
    _encerrado = true;
    _timer?.cancel();
    if (_banco != null) unawaited(_banco!.fechar().catchError((Object _) {}));
    super.dispose();
  }
}
