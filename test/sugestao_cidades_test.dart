import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:climasense/services/clima_api.dart';
import 'package:climasense/services/sugestao_cidades_service.dart';

void main() {
  Map<String, dynamic> municipio(String nome, String uf, String estado) => {
    'nome': nome,
    'regiao-imediata': {
      'regiao-intermediaria': {
        'UF': {'sigla': uf, 'nome': estado},
      },
    },
  };
  test(
    'sugere nomes reais com acentos, troca e inversão de letras; reutiliza catálogo',
    () async {
      var chamadas = 0;
      final servico = SugestaoCidadesService(
        MockClient((_) async {
          chamadas++;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                municipio('São Paulo', 'SP', 'São Paulo'),
                municipio('Campinas', 'SP', 'São Paulo'),
                municipio('Curitiba', 'PR', 'Paraná'),
              ]),
            ),
            200,
          );
        }),
      );
      for (final termo in ['sso paulo', 'sao paulo', '  SÃO   PAULO ']) {
        expect((await servico.sugerir(termo)).first.nome, 'São Paulo');
      }
      expect((await servico.sugerir('campians')).first.nome, 'Campinas');
      expect(await servico.sugerir('zzzzzzzzzzzzzz'), isEmpty);
      expect(chamadas, 1);
    },
  );
  test(
    'busca com erro resolve coordenadas e filtra o estado correto',
    () async {
      final api = ClimaApi(
        MockClient((r) async {
          if (r.url.host == 'servicodados.ibge.gov.br') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode([municipio('São Paulo', 'SP', 'São Paulo')]),
              ),
              200,
            );
          }
          final nome = r.url.queryParameters['name'];
          if (nome == 'sso paulo') return http.Response('{"results":[]}', 200);
          expect(nome, 'São Paulo');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'results': [
                  {
                    'name': 'São Paulo',
                    'admin1': 'Paraná',
                    'country': 'Brasil',
                    'country_code': 'BR',
                    'latitude': 0,
                    'longitude': 0,
                  },
                  {
                    'name': 'São Paulo',
                    'admin1': 'São Paulo',
                    'country': 'Brasil',
                    'country_code': 'BR',
                    'latitude': -23.55,
                    'longitude': -46.63,
                  },
                ],
              }),
            ),
            200,
          );
        }),
      );
      final cidades = await api.buscar('sso paulo');
      expect(cidades, hasLength(1));
      expect(cidades.single.latitude, -23.55);
      expect(cidades.single.nome, contains('São Paulo'));
    },
  );
}
