import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
import '../providers/dados_app.dart';
import '../features/consentimento/consentimento_page.dart';
import '../features/home/painel_principal.dart';
import '../features/alertas/detalhe_alerta_page.dart';
import '../features/ocorrencias/cadastro_page.dart';
import '../models/regra_alerta.dart';
import '../models/ocorrencia.dart';
import '../providers/dados_clima.dart';

class ClimaSenseApp extends StatefulWidget {
  final DadosClima? dadosClima;
  final DadosApp? dadosApp;
  const ClimaSenseApp({super.key, this.dadosClima, this.dadosApp});
  @override
  State<ClimaSenseApp> createState() => _ClimaSenseAppState();
}

class _ClimaSenseAppState extends State<ClimaSenseApp>
    with WidgetsBindingObserver {
  late final dados = widget.dadosApp ?? DadosApp();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dados.iniciar();
  }

  @override
  void dispose() {
    dados.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) dados.sincronizar();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: dados,
    builder: (context, _) => MaterialApp(
      title: 'ClimaSense',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR')],
      theme: criarTema(Brightness.light, altoContraste: dados.altoContraste),
      darkTheme: criarTema(Brightness.dark, altoContraste: dados.altoContraste),
      highContrastTheme: criarTema(Brightness.light, altoContraste: true),
      highContrastDarkTheme: criarTema(Brightness.dark, altoContraste: true),
      themeMode: dados.tema,
      onGenerateRoute: (settings) {
        if (settings.name == DetalheAlertaPage.rota &&
            settings.arguments is RegraAlerta) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                DetalheAlertaPage(alerta: settings.arguments! as RegraAlerta),
          );
        }
        if (settings.name == '/ocorrencia/nova') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => CadastroPage(dados: dados),
          );
        }
        if (settings.name == '/ocorrencia/editar' &&
            settings.arguments is Ocorrencia) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => CadastroPage(
              dados: dados,
              ocorrencia: settings.arguments! as Ocorrencia,
            ),
          );
        }
        return null;
      },
      home: dados.erroInicializacao != null
          ? Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dados.erroInicializacao!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: dados.iniciar,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : !dados.pronto
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : !dados.consentiu
          ? ConsentimentoPage(dados: dados)
          : PainelPrincipal(dados: dados, dadosClima: widget.dadosClima),
    ),
  );
}
