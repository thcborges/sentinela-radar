import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';

void main() {
  group('SentinelaTheme (Material Design 3 Dark HUD)', () {
    test('darkTheme deve ter useMaterial3 ativado e modo escuro', () {
      final theme = SentinelaTheme.darkTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(SentinelaTheme.surfaceDark));
    });

    test('Paleta de cores de alerta deve ter alto contraste semântico', () {
      expect(SentinelaTheme.alertNormal, equals(const Color(0xFF00E676)));
      expect(SentinelaTheme.alertWarning, equals(const Color(0xFFFFD600)));
      expect(SentinelaTheme.alertCritical, equals(const Color(0xFFFF1744)));
      expect(SentinelaTheme.alertInfo, equals(const Color(0xFF00B0FF)));
    });

    test('colorForAlertStatus deve retornar cor correta conforme severidade', () {
      expect(
        SentinelaTheme.colorForAlertStatus(AlertStatus.idle),
        equals(SentinelaTheme.alertNormal),
      );
      expect(
        SentinelaTheme.colorForAlertStatus(AlertStatus.approaching),
        equals(SentinelaTheme.alertWarning),
      );
      expect(
        SentinelaTheme.colorForAlertStatus(AlertStatus.alerting),
        equals(SentinelaTheme.alertWarning),
      );
      expect(
        SentinelaTheme.colorForAlertStatus(AlertStatus.overSpeed),
        equals(SentinelaTheme.alertCritical),
      );
      expect(
        SentinelaTheme.colorForAlertStatus(AlertStatus.passed),
        equals(SentinelaTheme.alertNormal),
      );
    });

    test('speedTextStyle deve usar números tabulares para evitar trepidação', () {
      final textStyle = SentinelaTheme.speedTextStyle;
      expect(textStyle.fontFeatures, isNotNull);
      expect(
        textStyle.fontFeatures!.any((f) => f.feature == 'tnum'),
        isTrue,
      );
    });
  });
}
