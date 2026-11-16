import 'dart:math' as math;
import 'package:flutter/material.dart';

class ColunaDado {
  final String rotulo;
  final double? valor;
  const ColunaDado(this.rotulo, this.valor);
}

/// Valores e rótulos permanecem acessíveis por toque, mouse e leitor de tela.
class GraficoColunas extends StatelessWidget {
  final List<ColunaDado> dados;
  final String unidade;
  const GraficoColunas({super.key, required this.dados, this.unidade = ''});

  String formatar(double valor) => valor == valor.roundToDouble()
      ? valor.toStringAsFixed(0)
      : valor.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (dados.isEmpty) return const Text('Sem dados para este período.');
    final cores = Theme.of(context).colorScheme;
    final maximo = dados.fold<double>(0, (m, d) => math.max(m, d.valor ?? 0));
    final passo = math.max(1, (maximo / 4).ceil()).toDouble();
    final teto = passo * 4;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sete dias cabem juntos no celular; listas maiores mantêm rolagem.
        final larguraMinima =
            dados.length <= 7 &&
                MediaQuery.textScalerOf(context).scale(12) <= 14
            ? 32.0
            : 66.0;
        final largura = math.max(
          constraints.maxWidth - 56,
          dados.length * larguraMinima,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              height: 232,
              child: Padding(
                padding: const EdgeInsets.only(top: 26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    5,
                    (i) => Text(
                      '${formatar(teto - passo * i)}${unidade.isEmpty ? '' : ' $unidade'}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: largura,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 232,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 32,
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  5,
                                  (_) => Divider(
                                    height: 1,
                                    color: cores.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: dados.map((d) {
                                final texto = d.valor == null
                                    ? 'Indisponível'
                                    : '${formatar(d.valor!)} $unidade'.trim();
                                return Expanded(
                                  child: Semantics(
                                    label: '${d.rotulo}: $texto',
                                    container: true,
                                    excludeSemantics: true,
                                    child: Tooltip(
                                      message: '${d.rotulo}: $texto',
                                      triggerMode: TooltipTriggerMode.tap,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                d.valor == null
                                                    ? '—'
                                                    : formatar(d.valor!),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelSmall,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TweenAnimationBuilder<double>(
                                              tween: Tween(
                                                begin: 0,
                                                end:
                                                    d.valor == null ||
                                                        d.valor == 0
                                                    ? 3
                                                    : 200 * d.valor! / teto,
                                              ),
                                              duration:
                                                  MediaQuery.disableAnimationsOf(
                                                    context,
                                                  )
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 450,
                                                    ),
                                              builder:
                                                  (
                                                    context,
                                                    altura,
                                                    child,
                                                  ) => Container(
                                                    height: altura,
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: d.valor == null
                                                          ? cores.outline
                                                          : cores.primary,
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: dados
                            .map(
                              (d) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child:
                                      RegExp(
                                        r'^\d{1,2}/\d{1,2}$',
                                      ).hasMatch(d.rotulo)
                                      ? FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            d.rotulo,
                                            maxLines: 1,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                        )
                                      : Text(
                                          d.rotulo,
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                        ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
