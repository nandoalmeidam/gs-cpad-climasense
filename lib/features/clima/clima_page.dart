import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/clima.dart';
import '../../providers/dados_clima.dart';
import '../../core/widgets/indicador.dart';
import '../../core/widgets/grafico_colunas.dart';
import '../../core/widgets/mapa_clima.dart';
import '../../services/localizacao_service.dart';

class ClimaPage extends StatefulWidget {
  final DadosClima dados;
  const ClimaPage({super.key, required this.dados});
  @override
  State<ClimaPage> createState() => _ClimaPageState();
}

class _ClimaPageState extends State<ClimaPage> {
  final busca = TextEditingController();
  Timer? timer;
  int versao = 0;
  List<Cidade> cidades = [];
  bool buscando = false;
  String? erro;
  bool localizando = false;
  Future<void> localizar() async {
    setState(() => localizando = true);
    try {
      final cidade = await LocalizacaoService().localizar();
      if (!mounted) return;
      await widget.dados.selecionar(cidade);
    } catch (e) {
      if (mounted) {
        setState(() => erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => localizando = false);
    }
  }

  Future<void> pesquisar() async {
    timer?.cancel();
    final atual = ++versao;
    final termo = busca.text.trim();
    setState(() {
      buscando = termo.length >= 2;
      cidades = [];
      erro = null;
    });
    if (termo.length < 2) return;
    try {
      final lista = await widget.dados.api.buscar(termo);
      if (!mounted || atual != versao) return;
      setState(() {
        cidades = lista;
        if (lista.isEmpty) erro = 'Nenhuma cidade encontrada.';
      });
    } catch (_) {
      if (mounted && atual == versao) {
        setState(
          () => erro = 'Não foi possível buscar cidades. Tente novamente.',
        );
      }
    } finally {
      if (mounted && atual == versao) setState(() => buscando = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.dados,
    builder: (context, _) {
      final d = widget.dados;
      final c = d.clima;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Clima', style: Theme.of(context).textTheme.headlineMedium),
          const Text('Confira o tempo na sua cidade.'),
          const SizedBox(height: 16),
          TextField(
            controller: busca,
            decoration: InputDecoration(
              labelText: 'Buscar cidade',
              hintText: 'Ex.: São Paulo',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Pesquisar',
                onPressed: pesquisar,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => pesquisar(),
            onChanged: (_) {
              ++versao;
              timer?.cancel();
              setState(() {
                cidades = [];
                buscando = false;
                erro = null;
              });
              timer = Timer(const Duration(milliseconds: 450), pesquisar);
            },
          ),
          if (buscando) const LinearProgressIndicator(),
          if (erro != null) Text(erro!),
          ...cidades.map(
            (cidade) => ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(cidade.nome),
              onTap: () {
                timer?.cancel();
                ++versao;
                setState(() {
                  cidades = [];
                  buscando = false;
                });
                FocusScope.of(context).unfocus();
                d.selecionar(cidade);
              },
            ),
          ),
          if (d.carregando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (d.erro != null) Text(d.erro!),
          if (d.cidade == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Escolha sua cidade para começar.'),
            ),
          if (d.cidade != null)
            TextButton.icon(
              onPressed: d.carregando ? null : () => d.selecionar(d.cidade!),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar dados'),
            ),
          if (c != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF123E52), Color(0xFF006B62)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white, fontSize: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.cidade!.nome),
                    const SizedBox(height: 16),
                    Icon(
                      c.codigo == 0
                          ? Icons.wb_sunny_rounded
                          : c.codigo >= 51
                          ? Icons.grain
                          : Icons.cloud_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                    Text(
                      '${c.temperatura.round()}°',
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(condicaoTempo(c.codigo)),
                    if (c.dias.isNotEmpty)
                      Text(
                        'Máx. ${c.dias.first.maxima.round()}° · Mín. ${c.dias.first.minima.round()}°',
                      ),
                    Text('Sensação de ${c.sensacao.round()}°'),
                    const SizedBox(height: 12),
                    Text(
                      'Atualizado: ${c.atualizado.replaceFirstMapped(RegExp(r'^(\d{4})-(\d{2})-(\d{2})'), (data) => '${data[3]}-${data[2]}-${data[1]}').replaceFirst('T', ' às ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Indicador(
                  'Umidade',
                  '${c.umidade.round()}%',
                  Icons.water_drop_outlined,
                ),
                Indicador('Vento', '${c.vento.round()} km/h', Icons.air),
                Indicador(
                  'Precipitação atual',
                  '${c.precipitacao.toStringAsFixed(1)} mm',
                  Icons.grain,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Previsão de 3 dias',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ...c.dias.map(
              (dia) => Card(
                child: ListTile(
                  title: Text('${dia.data} · ${condicaoTempo(dia.codigo)}'),
                  subtitle: Text(
                    '${dia.minima.round()}° / ${dia.maxima.round()}° · ${dia.chuva.toStringAsFixed(1)} mm\nRajadas: ${dia.vento.round()} km/h',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: localizando ? null : localizar,
            icon: const Icon(Icons.my_location),
            label: Text(localizando ? 'Localizando…' : 'Usar minha região'),
          ),
          const Text(
            'A localização é opcional e arredondada para consultar o clima da região.',
            style: TextStyle(fontSize: 12),
          ),
          PainelChuva(dados: d),
          MapaClima(dados: d),
          const SizedBox(height: 16),
          const Text(
            'Fonte: Open-Meteo · Dados de modelos meteorológicos, sujeitos a incertezas. Não são alertas oficiais.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    },
  );
}

class PainelChuva extends StatelessWidget {
  final DadosClima dados;
  const PainelChuva({super.key, required this.dados});
  String mm(double? valor) =>
      valor == null ? 'Indisponível' : '${valor.toStringAsFixed(1)} mm';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: dados,
    builder: (context, _) {
      final h = dados.historico;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Histórico de precipitação',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (dados.cidade != null) Text(dados.cidade!.nome),
              if (dados.cidade == null)
                const Text('Selecione uma cidade na aba Clima.'),
              if (dados.erroHistorico != null) Text(dados.erroHistorico!),
              if (h != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Indicador(
                      'Hoje até a última hora',
                      mm(h.acumuladoHoje),
                      Icons.today,
                    ),
                    Indicador(
                      'Últimas 24 horas',
                      mm(h.ultimas24Horas),
                      Icons.water_drop,
                    ),
                    Indicador(
                      '7 dias completos',
                      mm(h.ultimos7Dias),
                      Icons.date_range,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Acumulado diário · últimos 7 dias completos'),
                const SizedBox(height: 16),
                GraficoColunas(
                  dados: h.dias
                      .map((d) => ColunaDado(d.data, d.milimetros))
                      .toList(),
                  unidade: 'mm',
                ),
                const SizedBox(height: 16),
                const Text(
                  '1 mm de chuva equivale a 1 litro por m². Os totais consideram horas completas. Os valores vêm de modelos meteorológicos e podem diferir das medições no seu bairro. Quando faltam dados, mostramos “Indisponível”.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
