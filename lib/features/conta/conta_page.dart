import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../providers/dados_app.dart';

class ContaPage extends StatefulWidget {
  final DadosApp dados;
  const ContaPage({super.key, required this.dados});
  @override
  State<ContaPage> createState() => _ContaPageState();
}

class _ContaPageState extends State<ContaPage> {
  final formulario = GlobalKey<FormState>();
  final email = TextEditingController(),
      senha = TextEditingController(),
      confirmar = TextEditingController();
  bool criar = true, ocupado = false, ocultar = true;
  String? mensagem;
  @override
  void dispose() {
    email.dispose();
    senha.dispose();
    confirmar.dispose();
    super.dispose();
  }

  String falha(Object erro) {
    if (erro is StateError) return erro.message;
    if (erro is FirebaseAuthException) {
      return switch (erro.code) {
        'email-already-in-use' || 'credential-already-in-use' =>
          'Este e-mail já tem uma conta. Use Entrar.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Não foi possível entrar. Confira o e-mail e a senha.',
        'weak-password' => 'Escolha uma senha mais forte.',
        'invalid-email' => 'Confira o endereço de e-mail.',
        'too-many-requests' =>
          'Muitas tentativas. Aguarde um pouco e tente novamente.',
        'network-request-failed' =>
          'Sem conexão. Seus registros locais continuam salvos.',
        'operation-not-allowed' =>
          'O acesso por e-mail ainda não está disponível. Tente novamente mais tarde.',
        _ => 'Não foi possível concluir. Tente novamente.',
      };
    }
    return 'Não foi possível concluir. Tente novamente.';
  }

  Future<void> executar(Future<void> Function() operacao) async {
    setState(() {
      ocupado = true;
      mensagem = null;
    });
    try {
      await operacao();
    } catch (e) {
      if (mounted) setState(() => mensagem = falha(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> salvar() async {
    if (!formulario.currentState!.validate()) return;
    await executar(() async {
      await widget.dados.acessarConta(
        email: email.text,
        senha: senha.text,
        criar: criar,
      );
      senha.clear();
      confirmar.clear();
      if (mounted) {
        setState(
          () => mensagem =
              'Conta conectada. Acompanhe a sincronização no Histórico.',
        );
      }
    });
  }

  Future<void> recuperar() async {
    final endereco = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(endereco)) {
      setState(() => mensagem = 'Preencha seu e-mail para recuperar a senha.');
      return;
    }
    await executar(() async {
      await widget.dados.conta!.recuperarSenha(endereco);
      if (mounted) {
        setState(
          () => mensagem =
              'Se houver uma conta com esse e-mail, você receberá as instruções. Confira também o spam.',
        );
      }
    });
  }

  Future<void> sair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'O histórico desta conta ficará separado neste aparelho. Entre novamente para acessá-lo. Alterações pendentes precisam ser sincronizadas antes de sair.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await executar(widget.dados.sairDaConta);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minha conta')),
    body: AnimatedBuilder(
      animation: widget.dados,
      builder: (context, _) {
        final conta = widget.dados.conta;
        return Form(
          key: formulario,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (conta?.contaPermanente == true) ...[
                const Icon(Icons.account_circle_outlined, size: 56),
                const SizedBox(height: 12),
                Text(
                  conta!.email ?? 'Conta conectada',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Seu histórico pode ser recuperado em outro aparelho com este e-mail e senha. Ative a cópia na nuvem e aguarde a confirmação no Histórico.',
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: ocupado ? null : sair,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta'),
                ),
              ] else ...[
                Text(
                  criar
                      ? 'Guarde seu histórico com uma conta'
                      : 'Entre para recuperar seu histórico',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  criar
                      ? 'A conta é opcional. Ela mantém os registros desta instalação e permite acessá-los em outro aparelho após sincronizar.'
                      : 'Os registros da conta serão carregados. Os registros do visitante ficam separados neste aparelho e não são enviados para a outra conta.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: email,
                  enabled: !ocupado,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch((v ?? '').trim())
                      ? null
                      : 'Informe um e-mail válido.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: senha,
                  enabled: !ocupado,
                  obscureText: ocultar,
                  autofillHints: [
                    criar ? AutofillHints.newPassword : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    helperText: criar ? 'Use pelo menos 8 caracteres.' : null,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: ocultar ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: () => setState(() => ocultar = !ocultar),
                      icon: Icon(
                        ocultar
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => (v ?? '').length < (criar ? 8 : 1)
                      ? 'Confira sua senha.'
                      : null,
                ),
                if (criar) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmar,
                    enabled: !ocupado,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar senha',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == senha.text
                        ? null
                        : 'As senhas precisam ser iguais.',
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: ocupado ? null : salvar,
                  child: Text(criar ? 'Criar conta e sincronizar' : 'Entrar'),
                ),
                TextButton(
                  onPressed: ocupado
                      ? null
                      : () => setState(() {
                          criar = !criar;
                          mensagem = null;
                          senha.clear();
                          confirmar.clear();
                        }),
                  child: Text(
                    criar ? 'Já tenho uma conta' : 'Quero criar uma conta',
                  ),
                ),
                if (!criar)
                  TextButton(
                    onPressed: ocupado ? null : recuperar,
                    child: const Text('Esqueci minha senha'),
                  ),
              ],
              if (ocupado)
                const LinearProgressIndicator(
                  semanticsLabel: 'Conectando à conta',
                ),
              if (mensagem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(mensagem!)),
                ),
            ],
          ),
        );
      },
    ),
  );
}
