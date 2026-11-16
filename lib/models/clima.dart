class Cidade {
  final String nome;
  final double latitude, longitude;
  const Cidade(this.nome, this.latitude, this.longitude);
}

class PrevisaoDia {
  final String data;
  final double chuva, vento;
  final double minima, maxima;
  final int codigo;
  const PrevisaoDia(
    this.data,
    this.chuva,
    this.vento, {
    this.minima = 0,
    this.maxima = 0,
    this.codigo = 0,
  });
}

class ClimaInfo {
  final double temperatura, umidade, precipitacao;
  final List<PrevisaoDia> dias;
  final double sensacao, vento;
  final int codigo;
  final String atualizado;
  const ClimaInfo(
    this.temperatura,
    this.umidade,
    this.precipitacao,
    this.dias, {
    this.sensacao = 0,
    this.vento = 0,
    this.codigo = 0,
    this.atualizado = '',
  });
}

String condicaoTempo(int codigo) {
  if (codigo == 0) return 'Céu limpo';
  if (codigo <= 3) return 'Parcialmente nublado';
  if (codigo <= 48) return 'Nevoeiro';
  if (codigo <= 67) return 'Chuva';
  if (codigo <= 77) return 'Neve';
  if (codigo <= 82) return 'Pancadas de chuva';
  if (codigo <= 86) return 'Pancadas de neve';
  return 'Trovoadas';
}
