import '../engine/alert_machine.dart';
import '../l10n/app_language.dart';
import '../models/poi_model.dart';

/// Formatador de frases multilíngues (pt-BR, en-US, es-ES) para síntese
/// de voz local offline (Google TTS no Android e AVSpeechSynthesizer no iOS).
class TtsAlertFormatter {
  TtsAlertFormatter._();

  /// Gera a frase falada concisa e objetiva para o condutor no idioma selecionado.
  static String formatSpokenAlert(
    ActiveAlert alert, {
    AppLanguage language = AppLanguage.pt,
  }) {
    final baseText = formatPoiAlert(alert.poi, language: language);

    if (alert.isOverSpeed) {
      switch (language) {
        case AppLanguage.pt:
          return 'Atenção: Reduza a velocidade. $baseText';
        case AppLanguage.en:
          return 'Warning: Reduce your speed. $baseText';
        case AppLanguage.es:
          return 'Atención: Reduzca la velocidad. $baseText';
      }
    }

    return baseText;
  }

  /// Gera a frase falada correspondente a um POI individual no idioma selecionado.
  static String formatPoiAlert(
    PoiPoint poi, {
    AppLanguage language = AppLanguage.pt,
  }) {
    final type = poi.type;
    final speed = poi.speedLimit;

    switch (language) {
      case AppLanguage.pt:
        return _formatPt(type, speed);
      case AppLanguage.en:
        return _formatEn(type, speed);
      case AppLanguage.es:
        return _formatEs(type, speed);
    }
  }

  static String _formatPt(PoiType type, int? speed) {
    switch (type) {
      case PoiType.fixedRadar:
        return speed != null
            ? 'Radar fixo, $speed km/h à frente'
            : 'Radar fixo à frente';
      case PoiType.mobileRadar:
        return speed != null
            ? 'Atenção: Possível radar móvel, $speed km/h à frente'
            : 'Atenção: Possível radar móvel à frente';
      case PoiType.trafficLightRadar:
        return speed != null
            ? 'Semáforo com radar, $speed km/h à frente'
            : 'Semáforo com fiscalização de sinal à frente';
      case PoiType.redLightCamera:
        return 'Atenção: Fiscalização de sinal vermelho à frente';
      case PoiType.electronicSpeedBump:
        return speed != null
            ? 'Lombada eletrônica, $speed km/h à frente'
            : 'Lombada eletrônica à frente';
      case PoiType.physicalSpeedBump:
        return 'Atenção: Lombada à frente';
      case PoiType.tollBooth:
        return 'Praça de pedágio à frente';
      case PoiType.freeFlowToll:
        return 'Pórtico Free Flow à frente. Pedágio automático sem cancela';
      case PoiType.highwayPatrol:
        return 'Posto da polícia rodoviária à frente';
    }
  }

  static String _formatEn(PoiType type, int? speed) {
    switch (type) {
      case PoiType.fixedRadar:
        return speed != null
            ? 'Fixed speed camera, $speed km/h ahead'
            : 'Fixed speed camera ahead';
      case PoiType.mobileRadar:
        return speed != null
            ? 'Warning: Possible mobile radar, $speed km/h ahead'
            : 'Warning: Possible mobile radar ahead';
      case PoiType.trafficLightRadar:
        return speed != null
            ? 'Traffic light camera, $speed km/h ahead'
            : 'Traffic light camera ahead';
      case PoiType.redLightCamera:
        return 'Warning: Red light camera ahead';
      case PoiType.electronicSpeedBump:
        return speed != null
            ? 'Electronic speed bump, $speed km/h ahead'
            : 'Electronic speed bump ahead';
      case PoiType.physicalSpeedBump:
        return 'Warning: Speed bump ahead';
      case PoiType.tollBooth:
        return 'Toll plaza ahead';
      case PoiType.freeFlowToll:
        return 'Free Flow toll gantry ahead. Automatic toll';
      case PoiType.highwayPatrol:
        return 'Highway patrol station ahead';
    }
  }

  static String _formatEs(PoiType type, int? speed) {
    switch (type) {
      case PoiType.fixedRadar:
        return speed != null
            ? 'Radar fijo, $speed km/h adelante'
            : 'Radar fijo adelante';
      case PoiType.mobileRadar:
        return speed != null
            ? 'Atención: Posible radar móvil, $speed km/h adelante'
            : 'Atención: Posible radar móvil adelante';
      case PoiType.trafficLightRadar:
        return speed != null
            ? 'Semáforo con radar, $speed km/h adelante'
            : 'Semáforo con cámara adelante';
      case PoiType.redLightCamera:
        return 'Atención: Cámara de semáforo adelante';
      case PoiType.electronicSpeedBump:
        return speed != null
            ? 'Reductor electrónico, $speed km/h adelante'
            : 'Reductor electrónico adelante';
      case PoiType.physicalSpeedBump:
        return 'Atención: Resalto adelante';
      case PoiType.tollBooth:
        return 'Peaje adelante';
      case PoiType.freeFlowToll:
        return 'Pórtico Free Flow adelante. Peaje automático';
      case PoiType.highwayPatrol:
        return 'Puesto de policía de carreteras adelante';
    }
  }
}
