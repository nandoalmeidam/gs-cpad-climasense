import 'package:flutter/material.dart';

class Cabecalho extends StatelessWidget {
  final String titulo, subtitulo;
  const Cabecalho(this.titulo, this.subtitulo, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(subtitulo),
      ],
    ),
  );
}
