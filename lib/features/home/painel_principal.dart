import 'package:flutter/material.dart';
import '../../providers/dados_app.dart';
import '../../providers/dados_clima.dart';
import '../../models/regra_alerta.dart';
import '../ocorrencias/cadastro_page.dart';
import '../clima/clima_page.dart';
import '../alertas/alertas_page.dart';
import '../historico/historico_page.dart';
import 'inicio_page.dart';

class PainelPrincipal extends StatefulWidget {
  final DadosApp dados;
  final DadosClima? dadosClima;
  const PainelPrincipal({super.key, required this.dados, this.dadosClima});
  @override
  State<PainelPrincipal> createState() => _PainelPrincipalState();
}

class _PainelPrincipalState extends State<PainelPrincipal>
    with SingleTickerProviderStateMixin {
  int pagina = 0;
  late final clima = widget.dadosClima ?? DadosClima();
  late final AnimationController transicao;
  void navegar(int indice) {
    setState(() => pagina = indice);
    if (!MediaQuery.disableAnimationsOf(context)) transicao.forward(from: 0);
  }

  void verificarClima() {
    if (!clima.carregando) {
      widget.dados.verificarNotificacoes(
        avaliarClima(clima.clima, clima.cidade),
      );
    }
  }

  Future<void> abrirNotificacaoInicial() async {
    if (!widget.dados.notificacoes) return;
    try {
      await widget.dados.avisos.restaurarAbertura();
    } catch (erro) {
      debugPrint('Inicialização das notificações: $erro');
    }
  }

  @override
  void initState() {
    super.initState();
    transicao = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    clima.addListener(verificarClima);
    widget.dados.avisos.aoAbrirAlerta = () {
      if (mounted) navegar(2);
    };
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => abrirNotificacaoInicial(),
    );
    if (widget.dadosClima == null) clima.iniciar();
  }

  @override
  void dispose() {
    widget.dados.avisos.aoAbrirAlerta = null;
    clima.dispose();
    transicao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      InicioPage(dados: widget.dados, navegar: navegar),
      ClimaPage(dados: clima),
      AlertasPage(dados: widget.dados, clima: clima),
      HistoricoPage(dados: widget.dados),
      CadastroPage(dados: widget.dados, embutido: true),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClimaSense'),
        actions: [
          IconButton(
            tooltip: 'Alto contraste',
            isSelected: widget.dados.altoContraste,
            icon: const Icon(Icons.contrast),
            onPressed: () =>
                widget.dados.alterarContraste(!widget.dados.altoContraste),
          ),
          PopupMenuButton<ThemeMode>(
            tooltip: 'Escolher tema',
            icon: const Icon(Icons.brightness_6_outlined),
            initialValue: widget.dados.tema,
            onSelected: widget.dados.alterarTema,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ThemeMode.system,
                child: Text('Tema do sistema'),
              ),
              PopupMenuItem(value: ThemeMode.light, child: Text('Tema claro')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Tema escuro')),
            ],
          ),
          IconButton(
            tooltip: 'Sobre o aplicativo',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'ClimaSense',
              applicationVersion: '1.2.2',
              children: [
                const Text(
                  'Desenvolvido para a Global Solution 2026.2 da FIAP. Reúne previsão do tempo e registros de ocorrências. Os avisos do app não são alertas oficiais.',
                ),
              ],
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: transicao,
          child: IndexedStack(index: pagina, children: telas),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: pagina,
        onDestinationSelected: navegar,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            label: 'Clima',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_location_alt_outlined),
            label: 'Registrar',
          ),
        ],
      ),
    );
  }
}
