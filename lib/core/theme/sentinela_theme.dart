import 'package:flutter/material.dart';
import 'package:sentinela/core/engine/alert_machine.dart';

/// Define o tema visual Google Material Design 3 (M3) do Sentinela
/// com foco em Dark HUD/Dashboard analítico de alto contraste.
class SentinelaTheme {
  SentinelaTheme._();

  // Superfícies e fundos Dark HUD
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceContainerDark = Color(0xFF1E1E1E);
  static const Color surfaceContainerHighDark = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighestDark = Color(0xFF333333);

  // Paleta Semântica de Alertas M3 de Alto Contraste
  static const Color alertNormal = Color(0xFF00E676); // Verde (Dentro do limite / Seguro)
  static const Color alertWarning = Color(0xFFFFD600); // Amarelo/Âmbar (Aproximação compatível)
  static const Color alertCritical = Color(0xFFFF1744); // Vermelho (Excesso de velocidade / Crítico)
  static const Color alertInfo = Color(0xFF00B0FF); // Azul (Pedágios e Postos Policiais)

  /// Mapeia o estado da máquina de alertas para sua respectiva cor semântica.
  static Color colorForAlertStatus(AlertStatus status) {
    switch (status) {
      case AlertStatus.idle:
      case AlertStatus.passed:
        return alertNormal;
      case AlertStatus.approaching:
      case AlertStatus.alerting:
        return alertWarning;
      case AlertStatus.overSpeed:
        return alertCritical;
    }
  }

  /// Estilo numérico do velocímetro com números tabulares para evitar trepidação visual.
  static const TextStyle speedTextStyle = TextStyle(
    fontSize: 76,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
    color: Colors.white,
  );

  /// Tema Dark padrão compatível com Material Design 3.
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      surface: surfaceDark,
      surfaceContainer: surfaceContainerDark,
      surfaceContainerHigh: surfaceContainerHighDark,
      surfaceContainerHighest: surfaceContainerHighestDark,
      primary: alertNormal,
      onPrimary: Colors.black,
      secondary: alertInfo,
      onSecondary: Colors.black,
      error: alertCritical,
      onError: Colors.white,
      outline: const Color(0xFF444444),
      onSurface: const Color(0xFFE0E0E0),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surfaceDark,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        color: surfaceContainerDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
