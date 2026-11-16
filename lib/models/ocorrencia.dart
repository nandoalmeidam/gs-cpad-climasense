class Ocorrencia {
  final String id, bairro, tipo, descricao;
  final DateTime data;
  const Ocorrencia(this.id, this.bairro, this.tipo, this.descricao, this.data);
  Map<String, dynamic> toJson() => {
    'id': id,
    'bairro': bairro,
    'tipo': tipo,
    'descricao': descricao,
    'data': data.toIso8601String(),
  };
  factory Ocorrencia.fromJson(Map<String, dynamic> x) => Ocorrencia(
    x['id'] as String,
    x['bairro'] as String,
    x['tipo'] as String,
    x['descricao'] as String,
    DateTime.parse(x['data'] as String),
  );
}
