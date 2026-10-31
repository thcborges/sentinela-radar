import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/l10n/app_language.dart';
import 'package:sentinela/core/platform/haptic_feedback_engine.dart';

void main() {
  group('AlertPreferences A11y & i18n Tests (BDD)', () {
    test('deve conter valores padrão adequados para acessibilidade e idioma', () {
      const prefs = AlertPreferences();
      expect(prefs.hapticEnabled, isTrue);
      expect(prefs.hapticIntensity, HapticIntensity.medium);
      expect(prefs.language, AppLanguage.pt);
      expect(prefs.highContrastMode, isFalse);
    });

    test('copyWith deve atualizar campos de acessibilidade e idioma', () {
      const prefs = AlertPreferences();
      final updated = prefs.copyWith(
        hapticEnabled: false,
        hapticIntensity: HapticIntensity.strong,
        language: AppLanguage.en,
        highContrastMode: true,
      );

      expect(updated.hapticEnabled, isFalse);
      expect(updated.hapticIntensity, HapticIntensity.strong);
      expect(updated.language, AppLanguage.en);
      expect(updated.highContrastMode, isTrue);
    });

    test('serialização e desserialização JSON deve preservar acessibilidade e idioma', () {
      const prefs = AlertPreferences(
        hapticEnabled: true,
        hapticIntensity: HapticIntensity.light,
        language: AppLanguage.es,
        highContrastMode: true,
      );

      final json = prefs.toJson();
      expect(json['hapticEnabled'], isTrue);
      expect(json['hapticIntensity'], 'light');
      expect(json['language'], 'es');
      expect(json['highContrastMode'], isTrue);

      final restored = AlertPreferences.fromJson(json);
      expect(restored.hapticEnabled, isTrue);
      expect(restored.hapticIntensity, HapticIntensity.light);
      expect(restored.language, AppLanguage.es);
      expect(restored.highContrastMode, isTrue);
    });
  });
}
