import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/poi_model.dart';
import 'app_language.dart';

/// Dicionário local completo de termos, mensagens e categorias em pt-BR, en-US e es-ES.
class AppLocalizations {
  final AppLanguage language;

  const AppLocalizations(this.language);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(AppLanguage.pt);
  }

  // Unidades e Textos Centrais
  String get speedUnit => 'km/h';
  String get metersUnit => 'm';

  // Dashboard / HUD
  String get appTitle => 'Sentinela';
  String get monitoringRoads => _val(
        pt: 'Monitorando vias...',
        en: 'Monitoring roads...',
        es: 'Monitoreando vías...',
      );
  String get speedLimitPrefix => _val(
        pt: 'Máx',
        en: 'Max',
        es: 'Máx',
      );
  String get reduceSpeedWarning => _val(
        pt: 'Atenção: Reduza a velocidade',
        en: 'Warning: Reduce your speed',
        es: 'Atención: Reduzca la velocidad',
      );
  String get tunnelDeadReckoning => _val(
        pt: 'Modo Túnel (Navegação Inercial)',
        en: 'Tunnel Mode (Dead Reckoning)',
        es: 'Modo Túnel (Navegación Inercial)',
      );
  String get gpsSignalSearching => _val(
        pt: 'Buscando sinal GPS...',
        en: 'Searching GPS signal...',
        es: 'Buscando señal GPS...',
      );
  String get gpsSignalOk => _val(
        pt: 'Sinal GPS Ativo',
        en: 'GPS Signal Active',
        es: 'Señal GPS Activa',
      );
  String get mirrorModeActive => _val(
        pt: 'Modo HUD Para-brisa Ativo',
        en: 'Windshield HUD Mirror Active',
        es: 'Modo HUD Parabrisas Activo',
      );
  String get reportPoiTooltip => _val(
        pt: 'Reportar Radar / Ponto Rápido',
        en: 'Quick Report Radar / Hazard',
        es: 'Reportar Radar / Peligro',
      );

  // Settings
  String get settingsTitle => _val(
        pt: 'Configurações',
        en: 'Settings',
        es: 'Configuración',
      );
  String get languageSectionTitle => _val(
        pt: 'Idioma do Aplicativo',
        en: 'App Language',
        es: 'Idioma de la Aplicación',
      );
  String get hapticFeedbackTitle => _val(
        pt: 'Feedback Háptico (Vibração)',
        en: 'Haptic Feedback (Vibration)',
        es: 'Respuesta Háptica (Vibración)',
      );
  String get hapticFeedbackSubtitle => _val(
        pt: 'Pulsos táteis em aproximação e excesso de velocidade',
        en: 'Tactile pulses for approaching cameras and over-speed alerts',
        es: 'Pulsos táctiles en aproximación y exceso de velocidad',
      );
  String get highContrastTitle => _val(
        pt: 'Modo Alto Contraste',
        en: 'High Contrast Mode',
        es: 'Modo Alto Contraste',
      );
  String get highContrastSubtitle => _val(
        pt: 'Reforço de bordas e contraste para alta visibilidade sob luz solar',
        en: 'High contrast borders and enhanced legibility under direct sunlight',
        es: 'Bordes reforzados y contraste optimizado para luz solar intensa',
      );
  String get speedToleranceTitle => _val(
        pt: 'Tolerância de Velocidade',
        en: 'Speed Tolerance',
        es: 'Tolerancia de Velocidad',
      );
  String get alertOnlyOverSpeedTitle => _val(
        pt: 'Alertar apenas em excesso de velocidade',
        en: 'Alert only when over speed limit',
        es: 'Alertar solo en exceso de velocidad',
      );

  // Nomes de POIs
  String poiTypeName(PoiType type) {
    switch (type) {
      case PoiType.fixedRadar:
        return _val(
          pt: 'Radar Fixo',
          en: 'Fixed Speed Camera',
          es: 'Radar Fijo',
        );
      case PoiType.mobileRadar:
        return _val(
          pt: 'Radar Móvel',
          en: 'Mobile Radar',
          es: 'Radar Móvil',
        );
      case PoiType.trafficLightRadar:
        return _val(
          pt: 'Semáforo com Radar',
          en: 'Traffic Light Camera',
          es: 'Semáforo con Radar',
        );
      case PoiType.redLightCamera:
        return _val(
          pt: 'Avanço de Sinal',
          en: 'Red Light Camera',
          es: 'Cámara de Semáforo',
        );
      case PoiType.electronicSpeedBump:
        return _val(
          pt: 'Lombada Eletrônica',
          en: 'Electronic Speed Bump',
          es: 'Reductor Electrónico',
        );
      case PoiType.physicalSpeedBump:
        return _val(
          pt: 'Lombada Física',
          en: 'Speed Bump',
          es: 'Resalto / Badén',
        );
      case PoiType.tollBooth:
        return _val(
          pt: 'Praça de Pedágio',
          en: 'Toll Plaza',
          es: 'Peaje',
        );
      case PoiType.freeFlowToll:
        return _val(
          pt: 'Pórtico Free Flow',
          en: 'Free Flow Toll Gantry',
          es: 'Pórtico Free Flow',
        );
      case PoiType.highwayPatrol:
        return _val(
          pt: 'Polícia Rodoviária',
          en: 'Highway Patrol',
          es: 'Policía de Carreteras',
        );
    }
  }

  String _val({required String pt, required String en, required String es}) {
    switch (language) {
      case AppLanguage.pt:
        return pt;
      case AppLanguage.en:
        return en;
      case AppLanguage.es:
        return es;
    }
  }
}

/// Delegado do Flutter para injeção nativa de internacionalização.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['pt', 'en', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations(AppLanguage.fromCode(locale.languageCode)),
    );
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
