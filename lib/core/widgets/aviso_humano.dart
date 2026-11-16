import 'package:flutter/material.dart';

class AvisoHumano extends StatelessWidget {
  const AvisoHumano({super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Estes avisos não são oficiais. Confira as informações dos órgãos responsáveis antes de decidir o que fazer.',
            ),
          ),
        ],
      ),
    ),
  );
}
