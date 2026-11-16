import 'package:flutter/material.dart';
import '../../models/regra_alerta.dart';
import '../../core/widgets/aviso_humano.dart';

class DetalheAlertaPage extends StatelessWidget {
  static const rota = '/alerta';
  final RegraAlerta alerta;
  const DetalheAlertaPage({super.key, required this.alerta});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sobre este aviso')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(alerta.titulo, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text('Nível: ${alerta.nivel}'),
        const SizedBox(height: 16),
        Text('O que observamos: ${alerta.evidencia}'),
        const SizedBox(height: 16),
        Text('O que considerar: ${alerta.limitacao}'),
        const SizedBox(height: 16),
        const Text(
          'Com esses dados, não conseguimos calcular a chance de um problema acontecer. Acompanhe as orientações dos órgãos responsáveis pela sua região.',
        ),
        const AvisoHumano(),
      ],
    ),
  );
}
