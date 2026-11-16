import 'package:flutter/material.dart';

class Indicador extends StatelessWidget {
  final String titulo, valor;
  final IconData icone;
  const Indicador(this.titulo, this.valor, this.icone, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              valor,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            Text(titulo),
          ],
        ),
      ),
    ),
  );
}
