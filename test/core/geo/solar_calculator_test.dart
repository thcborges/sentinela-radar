import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/geo/solar_calculator.dart';

void main() {
  group('SolarCalculator (Cálculo Crepuscular e Solar 100% Offline para HUD M3)', () {
    // São Paulo (SP)
    const double spLat = -23.5505;
    const double spLon = -46.6333;

    test('deve identificar meio-dia como horário diurno em São Paulo', () {
      final noon = DateTime(2026, 10, 30, 12, 0, 0); // Horário de verão/padrão em SP
      final isDay = SolarCalculator.isDaytime(
        latitude: spLat,
        longitude: spLon,
        time: noon,
      );

      expect(isDay, isTrue);
    });

    test('deve identificar meia-noite como horário noturno em São Paulo', () {
      final midnight = DateTime(2026, 10, 30, 0, 30, 0);
      final isDay = SolarCalculator.isDaytime(
        latitude: spLat,
        longitude: spLon,
        time: midnight,
      );

      expect(isDay, isFalse);
    });

    test('deve calcular nascer e pôr do sol em horários realistas para o Brasil', () {
      final date = DateTime(2026, 10, 30);
      final sunrise = SolarCalculator.calculateSunrise(
        latitude: spLat,
        longitude: spLon,
        date: date,
      );
      final sunset = SolarCalculator.calculateSunset(
        latitude: spLat,
        longitude: spLon,
        date: date,
      );

      expect(sunrise, isNotNull);
      expect(sunset, isNotNull);

      // Em outubro em SP, o sol nasce entre 05h e 06h30 e se põe entre 18h e 19h30
      expect(sunrise!.hour, inInclusiveRange(4, 7));
      expect(sunset!.hour, inInclusiveRange(17, 20));
      expect(sunset.isAfter(sunrise), isTrue);
    });

    test('deve resolver temas visuais através de HudThemeMode corretamente', () {
      // 1. Modo Forçado Dark: sempre escuro
      expect(HudThemeMode.darkOnly.shouldUseDarkTheme(isDaytime: true, isTunnel: false), isTrue);
      expect(HudThemeMode.darkOnly.shouldUseDarkTheme(isDaytime: false, isTunnel: false), isTrue);

      // 2. Modo Forçado Day: sempre claro (exceto se em túnel para segurança da visão do motorista)
      expect(HudThemeMode.dayHighContrast.shouldUseDarkTheme(isDaytime: true, isTunnel: false), isFalse);
      expect(HudThemeMode.dayHighContrast.shouldUseDarkTheme(isDaytime: true, isTunnel: true), isTrue);

      // 3. Modo Solar Automático: claro de dia a céu aberto, escuro à noite ou em túnel
      expect(HudThemeMode.solarAutomatic.shouldUseDarkTheme(isDaytime: true, isTunnel: false), isFalse);
      expect(HudThemeMode.solarAutomatic.shouldUseDarkTheme(isDaytime: true, isTunnel: true), isTrue);
      expect(HudThemeMode.solarAutomatic.shouldUseDarkTheme(isDaytime: false, isTunnel: false), isTrue);
      expect(HudThemeMode.solarAutomatic.shouldUseDarkTheme(isDaytime: false, isTunnel: true), isTrue);
    });

    test('deve tratar latitudes extremas sem erro (ex: polos)', () {
      final northPole = DateTime(2026, 6, 21, 12, 0, 0); // Dia polar
      final isDay = SolarCalculator.isDaytime(
        latitude: 85.0,
        longitude: 0.0,
        time: northPole,
      );
      expect(isDay, isTrue);
    });
  });
}
