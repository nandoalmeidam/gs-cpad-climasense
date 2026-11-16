import 'package:flutter/material.dart';
import '../../core/widgets/aviso_humano.dart';
import '../../core/widgets/cabecalho.dart';
import '../../core/widgets/indicador.dart';
import '../../core/widgets/grafico_colunas.dart';
import '../../models/regra_alerta.dart';
import '../../models/analise_territorial.dart';
import '../../providers/dados_app.dart';
import '../../providers/dados_clima.dart';
import 'detalhe_alerta_page.dart';

class AlertasPage extends StatefulWidget {
  final DadosApp dados;
  final DadosClima clima;
  const AlertasPage({super.key, required this.dados, required this.clima});
  @override
  State<AlertasPage> createState() => _AlertasPageState();
}

class _AlertasPageState extends State<AlertasPage> {
  bool configurando = false;
  bool permissaoNegada = false;
  String? erroPermissao;
  Future<void> abrirConfiguracoes() async {
    try {
      final abriu = await widget.dados.avisos.abrirConfiguracoes();
      if (!abriu && mounted) {
        setState(
          () => erroPermissao =
              'Abra as configurações do celular, escolha ClimaSense e permita as notificações.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => erroPermissao =
              'Abra as configurações do celular, escolha ClimaSense e permita as notificações.',
        );
      }
    }
  }

  Future<void> notificacoes(bool ativar) async {
    setState(() {
      configurando = true;
      erroPermissao = null;
    });
    try {
      final ok = await widget.dados.configurarNotificacoes(ativar);
      if (mounted) setState(() => permissaoNegada = !ok);
      if (ok && ativar) {
        await widget.dados.verificarNotificacoes([
          ...avaliarOcorrencias(widget.dados.ocorrencias),
          ...avaliarClima(widget.clima.clima, widget.clima.cidade),
        ]);
      }
      if (mounted && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permita as notificações do ClimaSense nas configurações do celular.',
            ),
          ),
        );
      }
    } catch (erro) {
      debugPrint('Ativação das notificações: $erro');
      if (mounted) {
        setState(
          () => erroPermissao =
              'Não conseguimos ativar as notificações. Confira a permissão nas configurações do celular e tente novamente.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não conseguimos ativar as notificações. Veja as opções abaixo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => configurando = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.dados, widget.clima]),
    builder: (context, _) {
      final dados = widget.dados;
      final alertas = [
        ...avaliarClima(widget.clima.clima, widget.clima.cidade),
        ...avaliarOcorrencias(dados.ocorrencias),
      ];
      final agora = DateTime.now();
      final serie = serieOcorrencias(dados.ocorrencias, agora);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Cabecalho(
            'Alertas',
            'Acompanhe os avisos e veja o motivo de cada um.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Indicador(
                'Ocorrências',
                '${dados.ocorrencias.length}',
                Icons.report_outlined,
              ),
              Indicador(
                'Bairros com relatos',
                '${dados.porBairro().length}',
                Icons.location_city_outlined,
              ),
              Indicador(
                'Avisos ativos',
                '${alertas.where((a) => a.nivel != 'Informativo').length}',
                Icons.warning_amber,
              ),
            ],
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Receber notificações'),
                  subtitle: Text(
                    dados.avisos.suportado
                        ? 'Receba no celular os avisos de nível alto identificados ao abrir o app, atualizar o clima ou salvar uma ocorrência. O app não verifica novos dados enquanto está fechado.'
                        : 'Disponível no aplicativo instalado no celular. Aqui você pode consultar todos os avisos pela tela de Alertas.',
                  ),
                  value: dados.notificacoes && dados.avisos.suportado,
                  onChanged: configurando || !dados.avisos.suportado
                      ? null
                      : notificacoes,
                ),
                if (permissaoNegada || erroPermissao != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      erroPermissao ??
                          'As notificações estão bloqueadas. Permita o envio nas configurações do celular.',
                    ),
                  ),
                if (dados.avisos.suportado)
                  TextButton.icon(
                    onPressed: configurando ? null : abrirConfiguracoes,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Abrir configurações do celular'),
                  ),
                if (dados.erroNotificacao != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(dados.erroNotificacao!),
                  ),
              ],
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ocorrências na semana · ${tendenciaRegistros(serie)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  GraficoColunas(
                    dados: List.generate(7, (i) {
                      final data = DateTime(
                        agora.year,
                        agora.month,
                        agora.day,
                      ).subtract(Duration(days: 6 - i));
                      return ColunaDado(
                        '${data.day}/${data.month}',
                        serie[i].toDouble(),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Comparamos os últimos três dias com os três anteriores. Registros repetidos ou situações não relatadas podem mudar o resultado.',
                  ),
                ],
              ),
            ),
          ),
          if (widget.clima.clima == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Escolha uma cidade na aba Clima para ver também os avisos de chuva e vento.',
              ),
            ),
          ...alertas.map(
            (a) => Card(
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber,
                  color: a.nivel == 'Alto'
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(a.titulo),
                subtitle: Text('Nível: ${a.nivel}\n${a.evidencia}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(DetalheAlertaPage.rota, arguments: a),
              ),
            ),
          ),
          const AvisoHumano(),
        ],
      );
    },
  );
}
