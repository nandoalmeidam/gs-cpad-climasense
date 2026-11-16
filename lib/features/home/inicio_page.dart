import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/aviso_humano.dart';
import '../../providers/dados_app.dart';
import '../../core/widgets/indicador.dart';
import '../../models/analise_territorial.dart';

class InicioPage extends StatelessWidget {
  final DadosApp dados;
  final void Function(int) navegar;
  const InicioPage({super.key, required this.dados, required this.navegar});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'De olho no tempo',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Confira a previsão e acompanhe as ocorrências do seu bairro.',
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seus registros da região',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Indicador(
                    'Bairros com registros',
                    '${dados.porBairro().length}',
                    Icons.groups_outlined,
                  ),
                  Indicador(
                    'Últimos dias',
                    tendenciaRegistros(
                      serieOcorrencias(dados.ocorrencias, DateTime.now()),
                    ),
                    Icons.trending_up,
                  ),
                ],
              ),
              const Text(
                'Cada registro ajuda a acompanhar os problemas da região. A comparação considera os últimos três dias e os três anteriores.',
              ),
            ],
          ),
        ),
      ),
      _cartao(
        'Previsão do tempo',
        'Temperatura, chuva e previsão para os próximos dias.',
        Icons.cloud,
        () => navegar(1),
      ),
      _cartao(
        'Avisos da região',
        'Veja o que merece atenção e entenda o motivo.',
        Icons.shield_outlined,
        () => navegar(2),
      ),
      _cartao(
        'Histórico de ocorrências',
        dados.ocorrencias.isEmpty
            ? 'Seus registros ficam reunidos aqui.'
            : '${dados.ocorrencias.length} ${dados.ocorrencias.length == 1 ? 'ocorrência registrada' : 'ocorrências registradas'}.',
        Icons.analytics_outlined,
        () => navegar(3),
      ),
      _cartao(
        'Registrar ocorrência',
        'Conte o que aconteceu no seu bairro.',
        Icons.add_location_alt_outlined,
        () => navegar(4),
      ),
      const SizedBox(height: 12),
      const AvisoHumano(),
    ],
  );
  Widget _cartao(
    String titulo,
    String descricao,
    IconData icone,
    VoidCallback acao,
  ) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(18),
      leading: Icon(icone, color: verde, size: 34),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(descricao),
      trailing: const Icon(Icons.chevron_right),
      onTap: acao,
    ),
  );
}
