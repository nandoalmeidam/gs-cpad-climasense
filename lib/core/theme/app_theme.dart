import 'package:flutter/material.dart';

const azul = Color(0xFF123E52);
const verde = Color(0xFF008E82);

ThemeData criarTema(Brightness brilho, {bool altoContraste = false}) {
  final escuro = brilho == Brightness.dark;
  final cores = ColorScheme.fromSeed(
    seedColor: verde,
    brightness: brilho,
    contrastLevel: altoContraste ? 1 : 0,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: cores,
    scaffoldBackgroundColor: escuro
        ? const Color(0xFF101B20)
        : const Color(0xFFF2F6F7),
    appBarTheme: AppBarTheme(
      backgroundColor: escuro ? cores.surface : azul,
      foregroundColor: escuro ? cores.onSurface : Colors.white,
    ),
    cardTheme: CardThemeData(
      color: escuro ? cores.surfaceContainerLow : Colors.white,
      elevation: 0,
    ),
  );
}
