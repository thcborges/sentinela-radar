import 'dart:math' as math;

/// Modo de controle do tema visual do HUD (Dark vs High-Contrast Day).
enum HudThemeMode {
  /// Modo analítico escuro contínuo (#121212 / #1E1E1E).
  darkOnly,

  /// Modo diurno de alto contraste para visibilidade sob luz solar direta no para-brisa.
  dayHighContrast,

  /// Alternância automática baseada no cálculo solar/crepuscular e travessia de túneis.
  solarAutomatic;

  /// Determina se o painel deve renderizar superfícies escuras.
  bool shouldUseDarkTheme({required bool isDaytime, required bool isTunnel}) {
    if (isTunnel) return true; // Em túneis sempre escurece para conforto do motorista

    switch (this) {
      case HudThemeMode.darkOnly:
        return true;
      case HudThemeMode.dayHighContrast:
        return false;
      case HudThemeMode.solarAutomatic:
        return !isDaytime;
    }
  }
}

/// Calculador Solar e Crepuscular 100% Offline.
///
/// Implementa as equações de efemérides astronômicas da NOAA para determinar o
/// nascer e pôr do sol local e zênite solar a partir de coordenadas geográficas
/// sem necessidade de conexão com a internet.
class SolarCalculator {
  SolarCalculator._();

  static const double officialZenith = 90.8333; // 90° 50' oficial civil

  /// Calcula o ângulo de elevação solar (em graus decimais) no instante [time]
  /// para as coordenadas [latitude] e [longitude] com base no modelo de efemérides da NOAA.
  ///
  /// Retorna valores positivos quando o centro do sol está acima do horizonte astronômico,
  /// e valores negativos quando abaixo. O limite civil oficial considerando a refração
  /// atmosférica padrão é aproximadamente -0.8333° (90.8333° de distância zenital).
  static double calculateSolarElevation({
    required double latitude,
    required double longitude,
    required DateTime time,
  }) {
    final utc = time.toUtc();
    final dayOfYear = _getDayOfYear(utc);
    final utHour = utc.hour + (utc.minute / 60.0) + (utc.second / 3600.0);
    final t = dayOfYear + (utHour / 24.0);

    // 1. Anomalia Média do Sol
    final mDeg = (0.9856 * t) - 3.289;
    final mRad = _degToRad(mDeg);

    // 2. Longitude Verdadeira do Sol
    var lDeg = mDeg +
        (1.916 * math.sin(mRad)) +
        (0.020 * math.sin(2.0 * mRad)) +
        282.634;
    lDeg = _normalizeDegrees(lDeg);
    final lRad = _degToRad(lDeg);

    // 3. Ascensão Reta do Sol (RA)
    var raDeg = _radToDeg(math.atan(0.91764 * math.tan(lRad)));
    raDeg = _normalizeDegrees(raDeg);
    final lQuadrant = (lDeg / 90.0).floor() * 90.0;
    final raQuadrant = (raDeg / 90.0).floor() * 90.0;
    raDeg = raDeg + (lQuadrant - raQuadrant);
    final raHour = raDeg / 15.0;

    // 4. Declinação Solar
    final sinDec = 0.39782 * math.sin(lRad);
    final cosDec = math.cos(math.asin(sinDec));

    // 5. Ângulo Horário Local H (em graus)
    final hHour = utHour + (longitude / 15.0) - raHour + (0.06571 * t) + 6.622;
    final hRad = _degToRad(hHour * 15.0);

    // 6. Elevação Solar
    final latRad = _degToRad(latitude);
    final sinAltitude = (math.sin(latRad) * sinDec) +
        (math.cos(latRad) * cosDec * math.cos(hRad));
    return _radToDeg(math.asin(sinAltitude.clamp(-1.0, 1.0)));
  }

  /// Retorna [true] se o horário fornecido [time] estiver no período diurno
  /// na localização geográfica indicada (sol acima do horizonte civil).
  static bool isDaytime({
    required double latitude,
    required double longitude,
    required DateTime time,
  }) {
    final elevation = calculateSolarElevation(
      latitude: latitude,
      longitude: longitude,
      time: time,
    );
    // Limite oficial civil: centro do sol acima de -0.8333° (-50 minutos de arco)
    return elevation > -0.8333;
  }

  /// Calcula a data/hora local aproximada do nascer do sol.
  static DateTime? calculateSunrise({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) {
    return _calculateSolarEvent(
      latitude: latitude,
      longitude: longitude,
      date: date,
      isSunrise: true,
    );
  }

  /// Calcula a data/hora local aproximada do pôr do sol.
  static DateTime? calculateSunset({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) {
    return _calculateSolarEvent(
      latitude: latitude,
      longitude: longitude,
      date: date,
      isSunrise: false,
    );
  }

  static DateTime? _calculateSolarEvent({
    required double latitude,
    required double longitude,
    required DateTime date,
    required bool isSunrise,
  }) {
    final dayOfYear = _getDayOfYear(date);

    // 1. Aproximação do tempo
    final lngHour = longitude / 15.0;
    final t = isSunrise
        ? dayOfYear + ((6.0 - lngHour) / 24.0)
        : dayOfYear + ((18.0 - lngHour) / 24.0);

    // 2. Anomalia Média do Sol
    final mDeg = (0.9856 * t) - 3.289;
    final mRad = _degToRad(mDeg);

    // 3. Longitude Verdadeira do Sol
    var lDeg = mDeg +
        (1.916 * math.sin(mRad)) +
        (0.020 * math.sin(2.0 * mRad)) +
        282.634;
    lDeg = _normalizeDegrees(lDeg);
    final lRad = _degToRad(lDeg);

    // 4. Ascensão Reta do Sol (RA)
    var raDeg = _radToDeg(math.atan(0.91764 * math.tan(lRad)));
    raDeg = _normalizeDegrees(raDeg);

    // Ajuste de quadrante
    final lQuadrant = (lDeg / 90.0).floor() * 90.0;
    final raQuadrant = (raDeg / 90.0).floor() * 90.0;
    raDeg = raDeg + (lQuadrant - raQuadrant);
    final raHour = raDeg / 15.0;

    // 5. Declinação Solar
    final sinDec = 0.39782 * math.sin(lRad);
    final cosDec = math.cos(math.asin(sinDec));

    // 6. Ângulo Horário Local
    final cosZenith = math.cos(_degToRad(officialZenith));
    final latRad = _degToRad(latitude);
    final cosH = (cosZenith - (sinDec * math.sin(latRad))) /
        (cosDec * math.cos(latRad));

    if (cosH > 1.0 || cosH < -1.0) {
      return null; // Sol não nasce ou não se põe no dia
    }

    final hDeg = isSunrise
        ? 360.0 - _radToDeg(math.acos(cosH))
        : _radToDeg(math.acos(cosH));
    final hHour = hDeg / 15.0;

    // 7. Tempo Médio Local
    final tLocal = hHour + raHour - (0.06571 * t) - 6.622;

    // 8. Tempo Universal UTC (horas decimais)
    var utHour = tLocal - lngHour;
    while (utHour < 0.0) {
      utHour += 24.0;
    }
    while (utHour >= 24.0) {
      utHour -= 24.0;
    }

    final hours = utHour.floor();
    final remainderMinutes = (utHour - hours) * 60.0;
    final minutes = remainderMinutes.floor();
    final seconds = ((remainderMinutes - minutes) * 60.0).round();

    final utcEvent = DateTime.utc(
      date.year,
      date.month,
      date.day,
      hours,
      minutes,
      seconds,
    );

    return utcEvent.toLocal();
  }

  static int _getDayOfYear(DateTime date) {
    final diff = date.difference(DateTime(date.year, 1, 1));
    return diff.inDays + 1;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);

  static double _normalizeDegrees(double deg) {
    var d = deg % 360.0;
    if (d < 0.0) d += 360.0;
    return d;
  }
}
