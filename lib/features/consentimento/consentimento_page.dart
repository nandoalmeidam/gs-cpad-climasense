import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/dados_app.dart';

class ConsentimentoPage extends StatelessWidget {
  final DadosApp dados;
  const ConsentimentoPage({super.key, required this.dados});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.public, size: 74, color: verde),
                  const SizedBox(height: 18),
                  Text(
                    'Bem-vindo ao ClimaSense',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Os registros ficam salvos neste aparelho e podem ser consultados sem internet. Se você ativar a cópia na nuvem no Histórico, eles também serão enviados à sua área privada no Firebase. Uma conta por e-mail é opcional e permite recuperar as cópias sincronizadas em outro aparelho. Não inclua dados pessoais nas descrições. O clima usa Open-Meteo e IBGE; o mapa usa OpenStreetMap e RainViewer. Localização e notificações são opcionais.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: dados.consentir,
                    child: const Text('Entendi e concordo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
