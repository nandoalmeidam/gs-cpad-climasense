import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/dados_clima.dart';
import '../../services/radar_api.dart';

class MapaClima extends StatefulWidget {
  final DadosClima dados;
  final RadarApi? radar;
  const MapaClima({super.key, required this.dados, this.radar});
  @override
  State<MapaClima> createState() => _MapaClimaState();
}

class _MapaClimaState extends State<MapaClima> {
  late final radar = widget.radar ?? RadarApi(http.Client());
  bool aberto = false, carregando = false, falhaCamada = false;
  String? erro;
  List<ImagemRadar> imagens = [];
  int indice = 0;
  double selecao = 0;
  int versao = 0;

  @override
  void dispose() {
    if (widget.radar == null) radar.cliente.close();
    super.dispose();
  }

  Future<void> carregar({bool atualizar = false}) async {
    final atual = ++versao;
    setState(() {
      carregando = true;
      erro = null;
    });
    try {
      final resultado = await radar.consultar(atualizar: atualizar);
      if (!mounted || atual != versao) return;
      setState(() {
        imagens = resultado;
        indice = imagens.length - 1;
        selecao = indice.toDouble();
        falhaCamada = false;
      });
    } catch (_) {
      if (mounted && atual == versao) {
        setState(
          () => erro =
              'Não foi possível carregar o radar. Verifique a conexão e tente atualizar.',
        );
      }
    } finally {
      if (mounted && atual == versao) setState(() => carregando = false);
    }
  }

  void erroNoTile() {
    if (falhaCamada) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !falhaCamada) setState(() => falhaCamada = true);
    });
  }

  String horario(DateTime utc) {
    final d = utc.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} ${dois(d.hour)}:${dois(d.minute)}';
  }

  Future<void> fonte(String endereco) async {
    try {
      if (await launchUrl(
        Uri.parse(endereco),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* A URL também permanece visível no rótulo. */
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Acesse $endereco no navegador.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cidade = widget.dados.cidade;
    if (cidade == null) return const SizedBox.shrink();
    final centro = LatLng(cidade.latitude, cidade.longitude);
    final imagem = imagens.isEmpty ? null : imagens[indice];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mapa meteorológico · radar de chuva',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(cidade.nome),
            const Text(
              'Veja ecos de precipitação na região e compare imagens recentes do radar.',
            ),
            TextButton.icon(
              onPressed: () {
                setState(() => aberto = !aberto);
                if (aberto) carregar();
              },
              icon: const Icon(Icons.radar),
              label: Text(aberto ? 'Fechar radar' : 'Abrir mapa meteorológico'),
            ),
            if (aberto) ...[
              if (carregando)
                const LinearProgressIndicator(
                  semanticsLabel: 'Carregando imagens do radar',
                ),
              if (erro != null)
                Text(
                  erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (imagem != null) ...[
                Text(
                  'Imagem: ${horario(imagem.horarioUtc)} · horário do aparelho',
                ),
                const Text(
                  'Horário de geração do quadro; os radares podem ter atrasos diferentes.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      key: ValueKey('${cidade.latitude},${cidade.longitude}'),
                      options: MapOptions(
                        initialCenter: centro,
                        initialZoom: 7,
                        minZoom: 3,
                        maxZoom: 10,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'br.com.fiap.climasense',
                          keepBuffer: 0,
                        ),
                        TileLayer(
                          key: ValueKey(imagem.urlTemplate),
                          urlTemplate: imagem.urlTemplate,
                          userAgentPackageName: 'br.com.fiap.climasense',
                          maxNativeZoom: 7,
                          maxZoom: 10,
                          keepBuffer: 0,
                          errorTileCallback: (_, _, _) => erroNoTile(),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: centro,
                              width: 32,
                              height: 32,
                              child: Tooltip(
                                message: 'Região consultada: ${cidade.nome}',
                                child: Icon(
                                  Icons.location_on,
                                  size: 30,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (imagens.length > 1) ...[
                  Slider(
                    value: selecao,
                    min: 0,
                    max: (imagens.length - 1).toDouble(),
                    divisions: imagens.length - 1,
                    label: horario(imagens[selecao.round()].horarioUtc),
                    semanticFormatterCallback: (v) =>
                        'Imagem de ${horario(imagens[v.round()].horarioUtc)}',
                    onChanged: (v) => setState(() => selecao = v),
                    onChangeEnd: (v) => setState(() {
                      indice = v.round();
                      falhaCamada = false;
                    }),
                  ),
                  const Text(
                    'Arraste e solte para trocar o horário. Somente imagens passadas; não é previsão futura.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _Legenda(Color(0xFF00A3E0), '20 dBZ · mais fraco'),
                    _Legenda(Color(0xFFFFEE00), '35 dBZ'),
                    _Legenda(Color(0xFFFF4400), '45 dBZ · mais forte'),
                  ],
                ),
                const SizedBox(height: 8),
                if (falhaCamada)
                  Text(
                    'Uma ou mais imagens não carregaram. O mapa pode estar incompleto; tente atualizar.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Text(
                  'Áreas sem cor podem indicar ausência de ecos, falta de cobertura ou falha nos dados. Não significam ausência de risco. O radar não mostra o acumulado diário em mm dos gráficos.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
              TextButton.icon(
                onPressed: carregando ? null : () => carregar(atualizar: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar radar'),
              ),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => fonte('https://www.rainviewer.com'),
                    child: const Text(
                      'Weather data by RainViewer · rainviewer.com',
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        fonte('https://www.openstreetmap.org/copyright'),
                    child: const Text('© OpenStreetMap contributors'),
                  ),
                ],
              ),
              const Text(
                'Requer internet e cobertura de radar na região. Fontes: RainViewer (radar) e OpenStreetMap (mapa).',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color cor;
  final String texto;
  const _Legenda(this.cor, this.texto);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: cor,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      const SizedBox(width: 4),
      Text(texto, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}
