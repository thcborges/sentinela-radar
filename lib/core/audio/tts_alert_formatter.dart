import '../engine/alert_machine.dart';
import '../models/poi_model.dart';

/// Formatador de frases em português brasileiro (pt-BR) para síntese
/// de voz local offline (Google TTS no Android e AVSpeechSynthesizer no iOS).
class TtsAlertFormatter {
  TtsAlertFormatter._();

  /// Gera a frase falada concisa e objetiva para o condutor.
  static String formatSpokenAlert(ActiveAlert alert) {
    final baseText = formatPoiAlert(alert.poi);

    if (alert.isOverSpeed) {
      return 'Atenção: Reduza a velocidade. $baseText';
    }

    return baseText;
  }

  /// Gera a frase falada correspondente a um POI individual.
  static String formatPoiAlert(PoiPoint poi) {
    final type = poi.type;
    final speed = poi.speedLimit;

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
}
