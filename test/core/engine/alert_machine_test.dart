import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:test/test.dart';

void main() {
  group('AlertMachine State Machine', () {
    late AlertMachine alertMachine;

    // POI 1: Radar fixo de 60 km/h situado a ~300m ao Norte
    // (0.0027 graus de latitude ~ 300 metros)
    const radar60 = PoiPoint(
      id: 1,
      type: PoiType.fixedRadar,
      latitude: 0.0027,
      longitude: 0.0,
      speedLimit: 60,
      direction: 0, // Sentido Norte
      roadName: 'Av. Brasil',
    );

    // POI 2: Lombada física situada a ~100m ao Norte
    const speedBump = PoiPoint(
      id: 2,
      type: PoiType.physicalSpeedBump,
      latitude: 0.0009,
      longitude: 0.0,
      roadName: 'Rua das Flores',
    );

    setUp(() {
      alertMachine = AlertMachine();
    });

    tearDown(() {
      alertMachine.close();
    });

    test('estado inicial deve ser IDLE sem alerta ativo', () {
      expect(alertMachine.state.status, equals(AlertStatus.idle));
      expect(alertMachine.state.activeAlert, isNull);
      expect(alertMachine.state.nearbyAlerts, isEmpty);
    });

    test('deve ignorar posições com precisão GPS degradada (> 35m)', () {
      final noisyPos = VehiclePosition(
        latitude: 0.0,
        longitude: 0.0,
        speedKmh: 60.0,
        bearing: 0.0,
        accuracyMeters: 50.0, // GPS fraco
        timestamp: DateTime.now(),
      );

      alertMachine.updatePosition(noisyPos, [radar60]);

      expect(alertMachine.state.status, equals(AlertStatus.idle));
      expect(alertMachine.state.activeAlert, isNull);
    });

    test('deve transitar para APPROACHING quando dentro de D_approaching mas fora de D_alerta', () {
      // Radar a 300m. A 60 km/h: D_alerta = 250m. D_approaching = 375m.
      // Carro em (0, 0) andando para o Norte a 60 km/h -> distância ~300m -> APPROACHING
      final pos = VehiclePosition(
        latitude: 0.0,
        longitude: 0.0,
        speedKmh: 60.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );

      alertMachine.updatePosition(pos, [radar60]);

      expect(alertMachine.state.status, equals(AlertStatus.approaching));
      expect(alertMachine.state.activeAlert, isNotNull);
      expect(alertMachine.state.activeAlert!.poi.id, equals(1));
      expect(alertMachine.state.activeAlert!.distanceMeters, closeTo(300.0, 5.0));
    });

    test('deve transitar para ALERTING quando dentro de D_alerta com velocidade dentro do limite', () {
      // Carro em lat = 0.0009 (~100m do radar). Radar está a 60 km/h. Carro está a 55 km/h.
      final pos = VehiclePosition(
        latitude: 0.0009,
        longitude: 0.0,
        speedKmh: 55.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );

      alertMachine.updatePosition(pos, [radar60]);

      expect(alertMachine.state.status, equals(AlertStatus.alerting));
      expect(alertMachine.state.activeAlert!.isOverSpeed, isFalse);
    });

    test('deve transitar para OVER_SPEED quando dentro de D_alerta e velocidade acima do limite', () {
      // Carro em lat = 0.0009 (~100m do radar). Radar está a 60 km/h. Carro está a 75 km/h.
      final pos = VehiclePosition(
        latitude: 0.0009,
        longitude: 0.0,
        speedKmh: 75.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );

      alertMachine.updatePosition(pos, [radar60]);

      expect(alertMachine.state.status, equals(AlertStatus.overSpeed));
      expect(alertMachine.state.activeAlert!.isOverSpeed, isTrue);
    });

    test('deve descartar radar em via perpendicular ou sentido contrário', () {
      // Carro trafegando para Leste (90°), mas radar aponta para Norte (0°)
      final posPerpendicular = VehiclePosition(
        latitude: 0.0,
        longitude: 0.0,
        speedKmh: 60.0,
        bearing: 90.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );

      alertMachine.updatePosition(posPerpendicular, [radar60]);

      // Não deve disparar alerta para o radar
      expect(alertMachine.state.status, equals(AlertStatus.idle));
      expect(alertMachine.state.activeAlert, isNull);
    });

    test('priorização: POI em OVER_SPEED ou mais próximo tem precedência', () {
      // Dois POIs: Lombada a 100m e Radar a 300m
      // Carro a 75 km/h (acima do limite do radar de 60km/h)
      final pos = VehiclePosition(
        latitude: 0.0,
        longitude: 0.0,
        speedKmh: 75.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );

      alertMachine.updatePosition(pos, [radar60, speedBump]);

      // Lombada está a 100m (D_alerta a 75km/h ~ 166m -> ALERTING)
      // Radar a 300m (D_alerta a 75km/h ~ 312m -> OVER_SPEED!)
      // OVER_SPEED do radar deve ganhar prioridade de exibição
      expect(alertMachine.state.status, equals(AlertStatus.overSpeed));
      expect(alertMachine.state.activeAlert!.poi.id, equals(1));
      // Ambos devem estar presentes na lista de nearbyAlerts
      expect(alertMachine.state.nearbyAlerts.length, equals(2));
    });

    test('deve emitir PASSED quando o carro cruza o ponto e começa a se afastar', () {
      // 1. Carro se aproximando a 50m do radar
      final posApproaching = VehiclePosition(
        latitude: 0.00225,
        longitude: 0.0,
        speedKmh: 60.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );
      alertMachine.updatePosition(posApproaching, [radar60]);
      expect(alertMachine.state.status, equals(AlertStatus.alerting));

      // 2. Carro cruza o radar e agora está em lat = 0.0035 (o radar em 0.0027 ficou para trás!)
      final posPassed = VehiclePosition(
        latitude: 0.0035,
        longitude: 0.0,
        speedKmh: 60.0,
        bearing: 0.0, // Continua no mesmo rumo Norte
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );
      alertMachine.updatePosition(posPassed, [radar60]);
      expect(alertMachine.state.status, equals(AlertStatus.passed));

      // 3. Próxima coordenada longe volta para IDLE
      final posFar = VehiclePosition(
        latitude: 0.01,
        longitude: 0.0,
        speedKmh: 60.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );
      alertMachine.updatePosition(posFar, [radar60]);
      expect(alertMachine.state.status, equals(AlertStatus.idle));
    });

    test('reset deve forçar retorno imediato ao estado IDLE', () {
      final pos = VehiclePosition(
        latitude: 0.0009,
        longitude: 0.0,
        speedKmh: 75.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );
      alertMachine.updatePosition(pos, [radar60]);
      expect(alertMachine.state.status, equals(AlertStatus.overSpeed));

      alertMachine.reset();
      expect(alertMachine.state.status, equals(AlertStatus.idle));
      expect(alertMachine.state.activeAlert, isNull);
      expect(alertMachine.state.nearbyAlerts, isEmpty);
    });

    test('ActiveAlert e AlertState devem suportar props do Equatable', () {
      final alert1 = ActiveAlert(
        poi: radar60,
        distanceMeters: 200.0,
        currentSpeedKmh: 60.0,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0.0,
        relativeBearing: 0.0,
      );

      final alert2 = ActiveAlert(
        poi: radar60,
        distanceMeters: 200.0,
        currentSpeedKmh: 60.0,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0.0,
        relativeBearing: 0.0,
      );

      expect(alert1, equals(alert2));
      expect(alert1.props, equals(alert2.props));

      final state1 = AlertState(
        status: AlertStatus.alerting,
        activeAlert: alert1,
        nearbyAlerts: [alert1],
      );
      final state2 = AlertState(
        status: AlertStatus.alerting,
        activeAlert: alert2,
        nearbyAlerts: [alert2],
      );
      expect(state1, equals(state2));
      expect(state1.props, equals(state2.props));
    });

    test('ordenação de alertas com múltiplos status e desempates', () {
      // Três radares em distâncias diferentes
      const radarNear = PoiPoint(
        id: 10,
        type: PoiType.fixedRadar,
        latitude: 0.001,
        longitude: 0.0,
        speedLimit: 60,
      );
      const radarMid = PoiPoint(
        id: 20,
        type: PoiType.fixedRadar,
        latitude: 0.002,
        longitude: 0.0,
        speedLimit: 80,
      );
      const radarFar = PoiPoint(
        id: 30,
        type: PoiType.fixedRadar,
        latitude: 0.003,
        longitude: 0.0,
        speedLimit: 80,
      );

      // Carro a 70 km/h:
      // radarNear (60 km/h) -> overSpeed (pois v = 70 > 60)
      // radarMid (80 km/h) -> alerting (pois v = 70 <= 80)
      // radarFar (80 km/h) -> approaching
      final pos = VehiclePosition(
        latitude: 0.0,
        longitude: 0.0,
        speedKmh: 70.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime.now(),
      );

      alertMachine.updatePosition(pos, [radarFar, radarMid, radarNear]);

      expect(alertMachine.state.activeAlert!.poi.id, equals(10));
      expect(alertMachine.state.nearbyAlerts[0].poi.id, equals(10));
      expect(alertMachine.state.nearbyAlerts[1].poi.id, equals(20));
      expect(alertMachine.state.nearbyAlerts[2].poi.id, equals(30));
    });
  });
}
