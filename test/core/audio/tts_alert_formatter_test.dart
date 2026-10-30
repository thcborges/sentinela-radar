import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/audio/tts_alert_formatter.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('TtsAlertFormatter (Fala em Português pt-BR)', () {
    test('deve formatar anúncio falado para radar fixo com limite e distância', () {
      const poi = PoiPoint(
        id: 1,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.fixedRadar,
        speedLimit: 60,
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 400,
        currentSpeedKmh: 58,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      final speech = TtsAlertFormatter.formatSpokenAlert(alert);
      expect(speech, equals('Radar fixo, 60 km/h à frente'));
    });

    test('deve formatar anúncio falado para excesso de velocidade', () {
      const poi = PoiPoint(
        id: 2,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.fixedRadar,
        speedLimit: 80,
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 300,
        currentSpeedKmh: 95,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 0,
        relativeBearing: 0,
      );

      final speech = TtsAlertFormatter.formatSpokenAlert(alert);
      expect(speech, equals('Atenção: Reduza a velocidade. Radar fixo, 80 km/h à frente'));
    });

    test('deve formatar anúncio falado para semáforo com radar e câmera', () {
      const poiRadar = PoiPoint(
        id: 3,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.trafficLightRadar,
        speedLimit: 50,
      );

      const alertRadar = ActiveAlert(
        poi: poiRadar,
        distanceMeters: 200,
        currentSpeedKmh: 45,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      expect(
        TtsAlertFormatter.formatSpokenAlert(alertRadar),
        equals('Semáforo com radar, 50 km/h à frente'),
      );

      const poiCamera = PoiPoint(
        id: 4,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.redLightCamera,
      );

      const alertCamera = ActiveAlert(
        poi: poiCamera,
        distanceMeters: 180,
        currentSpeedKmh: 40,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      expect(
        TtsAlertFormatter.formatSpokenAlert(alertCamera),
        equals('Atenção: Fiscalização de sinal vermelho à frente'),
      );
    });

    test('deve formatar anúncio falado para lombada e pedágio / Free Flow', () {
      const poiBump = PoiPoint(
        id: 5,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.physicalSpeedBump,
      );
      const alertBump = ActiveAlert(
        poi: poiBump,
        distanceMeters: 100,
        currentSpeedKmh: 30,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(
        TtsAlertFormatter.formatSpokenAlert(alertBump),
        equals('Atenção: Lombada à frente'),
      );

      const poiToll = PoiPoint(
        id: 6,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.tollBooth,
      );
      const alertToll = ActiveAlert(
        poi: poiToll,
        distanceMeters: 900,
        currentSpeedKmh: 80,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(
        TtsAlertFormatter.formatSpokenAlert(alertToll),
        equals('Praça de pedágio à frente'),
      );

      const poiFreeFlow = PoiPoint(
        id: 7,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.freeFlowToll,
      );
      const alertFreeFlow = ActiveAlert(
        poi: poiFreeFlow,
        distanceMeters: 800,
        currentSpeedKmh: 90,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(
        TtsAlertFormatter.formatSpokenAlert(alertFreeFlow),
        equals('Pórtico Free Flow à frente. Pedágio automático sem cancela'),
      );
    });

    test('deve cobrir casos sem limite de velocidade e tipos restantes', () {
      // Radar móvel com limite e sem limite
      const alertMobileLimit = ActiveAlert(
        poi: PoiPoint(id: 8, latitude: 0, longitude: 0, type: PoiType.mobileRadar, speedLimit: 70),
        distanceMeters: 300,
        currentSpeedKmh: 60,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(TtsAlertFormatter.formatSpokenAlert(alertMobileLimit),
          equals('Atenção: Possível radar móvel, 70 km/h à frente'));

      const alertMobileNoLimit = ActiveAlert(
        poi: PoiPoint(id: 9, latitude: 0, longitude: 0, type: PoiType.mobileRadar),
        distanceMeters: 300,
        currentSpeedKmh: 60,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(TtsAlertFormatter.formatSpokenAlert(alertMobileNoLimit),
          equals('Atenção: Possível radar móvel à frente'));

      // Radar fixo sem limite
      const alertFixedNoLimit = ActiveAlert(
        poi: PoiPoint(id: 10, latitude: 0, longitude: 0, type: PoiType.fixedRadar),
        distanceMeters: 300,
        currentSpeedKmh: 60,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(TtsAlertFormatter.formatSpokenAlert(alertFixedNoLimit),
          equals('Radar fixo à frente'));

      // Semáforo com radar sem limite
      const alertTlRadarNoLimit = ActiveAlert(
        poi: PoiPoint(id: 11, latitude: 0, longitude: 0, type: PoiType.trafficLightRadar),
        distanceMeters: 200,
        currentSpeedKmh: 40,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(TtsAlertFormatter.formatSpokenAlert(alertTlRadarNoLimit),
          equals('Semáforo com fiscalização de sinal à frente'));

      // Lombada eletrônica com e sem limite
      const alertElecBumpLimit = ActiveAlert(
        poi: PoiPoint(id: 12, latitude: 0, longitude: 0, type: PoiType.electronicSpeedBump, speedLimit: 40),
        distanceMeters: 100,
        currentSpeedKmh: 35,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(TtsAlertFormatter.formatSpokenAlert(alertElecBumpLimit),
          equals('Lombada eletrônica, 40 km/h à frente'));

      const alertElecBumpNoLimit = ActiveAlert(
        poi: PoiPoint(id: 13, latitude: 0, longitude: 0, type: PoiType.electronicSpeedBump),
        distanceMeters: 100,
        currentSpeedKmh: 35,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(TtsAlertFormatter.formatSpokenAlert(alertElecBumpNoLimit),
          equals('Lombada eletrônica à frente'));

      // Polícia rodoviária
      const alertPatrol = ActiveAlert(
        poi: PoiPoint(id: 14, latitude: 0, longitude: 0, type: PoiType.highwayPatrol),
        distanceMeters: 500,
        currentSpeedKmh: 70,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );
      expect(TtsAlertFormatter.formatSpokenAlert(alertPatrol),
          equals('Posto da polícia rodoviária à frente'));
    });
  });
}
