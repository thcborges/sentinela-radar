import '../engine/alert_machine.dart';
import '../models/poi_model.dart';

/// Formatador de frases em português brasileiro (pt-BR) para síntese
/// de voz local offline (Google TTS no Android e AVSpeechSynthesizer no iOS).
class TtsAlertFormatter {
  TtsAlertFormatter._();

  /// Gera a frase falada concisa e objetiva para o condutor.
  static String formatSpokenAlert(ActiveAlert alert) {
    final type = alert.poi.type;
    final speed = alert.poi.speedLimit;

    String baseText;
    switch (type) {
      case PoiType.fixedRadar:
        baseText = speed != null
            ? 'Radar fixo, $speed km/h à frente'
            : 'Radar fixo à frente';
        break;
      case PoiType.mobileRadar:
        baseText = speed != null
            ? 'Atenção: Possível radar móvel, $speed km/h à frente'
            : 'Atenção: Possível radar móvel à frente';
        break;
      case PoiType.trafficLightRadar:
        baseText = speed != null
            ? 'Semáforo com radar, $speed km/h à frente'
            : 'Semáforo com fiscalização de sinal à frente';
        break;
      case PoiType.redLightCamera:
        baseText = 'Atenção: Fiscalização de sinal vermelho à frente';
        break;
      case PoiType.electronicSpeedBump:
        baseText = speed != null
            ? 'Lombada eletrônica, $speed km/h à frente'
            : 'Lombada eletrônica à frente';
        break;
      case PoiType.physicalSpeedBump:
        baseText = 'Atenção: Lombada à frente';
        break;
      case PoiType.tollBooth:
        baseText = 'Praça de pedágio à frente';
        break;
      case PoiType.freeFlowToll:
        baseText = 'Pórtico Free Flow à frente. Pedágio automático sem cancela';
        break;
      case PoiType.highwayPatrol:
        baseText = 'Posto da polícia rodoviária à frente';
        break;
    }

    if (alert.isOverSpeed) {
      return 'Atenção: Reduza a velocidade. $baseText';
    }

    return baseText;
  }
}
