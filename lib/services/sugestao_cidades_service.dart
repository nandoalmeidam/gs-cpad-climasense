import 'dart:convert';
import 'package:http/http.dart' as http;

class CidadeSugerida {
  final String nome;
  final String estado;
  final String estadoNome;

  const CidadeSugerida({
    required this.nome,
    required this.estado,
    this.estadoNome = '',
  });

  String get descricao => '$nome — $estado';
}

class SugestaoCidadesService {
  final http.Client cliente;

  SugestaoCidadesService(this.cliente);

  List<CidadeSugerida>? _cache;
  Future<List<CidadeSugerida>>? _carregamento;

  String normalizar(String texto) {
    const acentos = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const simples = 'aaaaaeeeeiiiiooooouuuuc';

    var resultado = texto.toLowerCase().trim();

    for (var i = 0; i < acentos.length; i++) {
      resultado = resultado.replaceAll(acentos[i], simples[i]);
    }

    return resultado.replaceAll(RegExp(r'\s+'), ' ');
  }

  // Distância de edição com transposição: reconhece erros como "sao"/"soa".
  int distancia(String a, String b) {
    final tabela = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (var i = 0; i <= a.length; i++) {
      tabela[i][0] = i;
    }

    for (var j = 0; j <= b.length; j++) {
      tabela[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final custo = a[i - 1] == b[j - 1] ? 0 : 1;

        var menor = [
          tabela[i - 1][j] + 1,
          tabela[i][j - 1] + 1,
          tabela[i - 1][j - 1] + custo,
        ].reduce((x, y) => x < y ? x : y);

        // Detecta inversão de duas letras consecutivas.
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          final troca = tabela[i - 2][j - 2] + 1;

          if (troca < menor) {
            menor = troca;
          }
        }

        tabela[i][j] = menor;
      }
    }

    return tabela[a.length][b.length];
  }

  // Reutiliza o catálogo e a requisição em andamento entre pesquisas próximas.
  Future<List<CidadeSugerida>> carregarCidades() {
    if (_cache != null) {
      return Future.value(_cache!);
    }

    return _carregamento ??= _buscarMunicipios()
        .then((cidades) {
          _cache = cidades;
          return cidades;
        })
        .catchError((Object erro) {
          _carregamento = null;
          throw erro;
        });
  }

  Future<List<CidadeSugerida>> _buscarMunicipios() async {
    final uri = Uri.parse(
      'https://servicodados.ibge.gov.br/api/v1/localidades/municipios',
    );

    final resposta = await cliente
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar os municípios.');
    }

    final dados = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
    final cidades = <CidadeSugerida>[];

    for (final item in dados) {
      final municipio = item as Map<String, dynamic>;

      final regiao = municipio['regiao-imediata'] as Map<String, dynamic>?;

      final intermediaria =
          regiao?['regiao-intermediaria'] as Map<String, dynamic>?;

      final micro = municipio['microrregiao'] as Map<String, dynamic>?;
      final meso = micro?['mesorregiao'] as Map<String, dynamic>?;
      final uf = (intermediaria?['UF'] ?? meso?['UF']) as Map<String, dynamic>?;

      final nome = municipio['nome'] as String?;
      final sigla = uf?['sigla'] as String?;

      if (nome != null && sigla != null) {
        cidades.add(
          CidadeSugerida(
            nome: nome,
            estado: sigla,
            estadoNome: uf?['nome'] as String? ?? '',
          ),
        );
      }
    }

    return cidades;
  }

  // Menor pontuação vem primeiro; null descarta uma correspondência distante.
  int? _pontuacao(String pesquisa, String nome) {
    if (nome == pesquisa) {
      return 0;
    }

    // Cidade começa exatamente com as letras digitadas.
    if (nome.startsWith(pesquisa)) {
      return 10;
    }

    // Exemplo: "Ss" pode encontrar "São Sebastião".
    final palavras = nome.split(' ');
    final iniciais = palavras
        .where((palavra) => palavra.isNotEmpty)
        .map((palavra) => palavra[0])
        .join();

    if (iniciais.startsWith(pesquisa)) {
      return 20;
    }

    // Para palavras muito curtas, evita sugestões aleatórias.
    if (pesquisa.length < 4) {
      return null;
    }

    final tolerancia = pesquisa.length >= 7 ? 3 : 2;

    // Compara o nome completo para reconhecer erros de digitação.
    final diferencaCompleta = distancia(pesquisa, nome);

    if (diferencaCompleta <= tolerancia) {
      return 30 + diferencaCompleta;
    }

    // Compara também o início de nomes maiores.
    // Exemplo: "Campians" e "Campinas".
    final tamanho = pesquisa.length;

    var menorDiferenca = tamanho + 1;

    for (var ajuste = -2; ajuste <= 2; ajuste++) {
      final limite = tamanho + ajuste;

      if (limite < 1 || limite > nome.length) {
        continue;
      }

      final prefixo = nome.substring(0, limite);
      final diferenca = distancia(pesquisa, prefixo);

      if (diferenca < menorDiferenca) {
        menorDiferenca = diferenca;
      }
    }

    if (menorDiferenca <= tolerancia) {
      return 40 + menorDiferenca;
    }

    return null;
  }

  Future<List<CidadeSugerida>> sugerir(String texto) async {
    final pesquisa = normalizar(texto);

    if (pesquisa.length < 2) {
      return [];
    }

    final cidades = await carregarCidades();

    final resultados = <CidadeSugerida>[];
    final pontuacoes = <CidadeSugerida, int>{};

    for (final cidade in cidades) {
      final nome = normalizar(cidade.nome);
      final pontuacao = _pontuacao(pesquisa, nome);

      if (pontuacao != null) {
        resultados.add(cidade);
        pontuacoes[cidade] = pontuacao;
      }
    }

    resultados.sort((a, b) {
      final prioridadeA = pontuacoes[a]!;
      final prioridadeB = pontuacoes[b]!;

      final comparacao = prioridadeA.compareTo(prioridadeB);

      if (comparacao != 0) {
        return comparacao;
      }

      final nomeA = normalizar(a.nome);
      final nomeB = normalizar(b.nome);

      final ordem = nomeA.compareTo(nomeB);

      if (ordem != 0) {
        return ordem;
      }

      return a.estado.compareTo(b.estado);
    });

    return resultados.take(15).toList();
  }
}
