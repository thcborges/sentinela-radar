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

      // Em outubro em SP (fuso horário oficial de Brasília UTC-3),
      // o sol nasce entre 05h e 06h30 local e se põe entre 18h e 19h30 local
      final spSunriseLocalHour = sunrise!.toUtc().subtract(const Duration(hours: 3)).hour;
      final spSunsetLocalHour = sunset!.toUtc().subtract(const Duration(hours: 3)).hour;
      expect(spSunriseLocalHour, inInclusiveRange(4, 7));
      expect(spSunsetLocalHour, inInclusiveRange(17, 20));
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

    test('BUG #32 REGRESSÃO: deve identificar noite polar contínua como horário noturno mesmo ao meio-dia', () {
      // Svalbard (78° N) no solstício de inverno: o sol nunca nasce
      final svalbardWinterNoon = DateTime(2026, 12, 21, 12, 0, 0);
      final isDayWinter = SolarCalculator.isDaytime(
        latitude: 78.0,
        longitude: 15.0,
        time: svalbardWinterNoon,
      );
      expect(isDayWinter, isFalse, reason: 'Noite polar em Svalbard no solstício de inverno deve ser escuro ao meio-dia');

      // Svalbard em transição (27 de outubro): nascer do sol e pôr do sol discordam, sol não alcança o horizonte
      final svalbardOctNoon = DateTime(2026, 10, 27, 12, 0, 0);
      final isDayOct = SolarCalculator.isDaytime(
        latitude: 78.0,
        longitude: 15.0,
        time: svalbardOctNoon,
      );
      expect(isDayOct, isFalse, reason: 'Em transição para noite polar onde o sol não passa do horizonte deve ser noturno ao meio-dia');

      // Antártica (-75° S) no inverno austral (21 de junho): solstício de inverno austral
      final antarcticaWinterNoon = DateTime(2026, 6, 21, 12, 0, 0);
      final isDayAntarctica = SolarCalculator.isDaytime(
        latitude: -75.0,
        longitude: 0.0,
        time: antarcticaWinterNoon,
      );
      expect(isDayAntarctica, isFalse, reason: 'Noite polar na Antártica deve ser noturno ao meio-dia em 21 de junho');
    });

    test('BUG #32 REGRESSÃO: deve identificar sol da meia-noite / dia polar contínuo como horário diurno à meia-noite', () {
      // Svalbard (78° N) no solstício de verão (21 de junho) à meia-noite
      final svalbardMidnight = DateTime(2026, 6, 21, 0, 0, 0);
      final isDayMidnight = SolarCalculator.isDaytime(
        latitude: 78.0,
        longitude: 15.0,
        time: svalbardMidnight,
      );
      expect(isDayMidnight, isTrue, reason: 'Sol da meia-noite em Svalbard deve ser diurno às 00:00');
    });

    test('deve calcular elevação solar com precisão astronômica em qualquer coordenada', () {
      final noonElevation = SolarCalculator.calculateSolarElevation(
        latitude: spLat,
        longitude: spLon,
        time: DateTime(2026, 10, 30, 12, 0, 0),
      );
      expect(noonElevation, greaterThan(60.0));

      final midnightElevation = SolarCalculator.calculateSolarElevation(
        latitude: spLat,
        longitude: spLon,
        time: DateTime(2026, 10, 30, 0, 30, 0),
      );
      expect(midnightElevation, lessThan(-30.0));
    });
  });
}
