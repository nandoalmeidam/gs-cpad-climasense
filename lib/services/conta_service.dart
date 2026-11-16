abstract interface class ContaService {
  String? get email;
  bool get contaPermanente;
  Future<String> criarConta(String email, String senha);
  Future<String> entrar(String email, String senha);
  Future<void> recuperarSenha(String email);
  Future<void> sair();
}
