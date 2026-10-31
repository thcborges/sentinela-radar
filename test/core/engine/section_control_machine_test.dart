import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/section_control_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('SectionControlMachine & AverageSpeedCorridor (BDD - Radar de Trecho / Velocidade Média)', () {
    const startPoint = PoiPoint(
      id: 901,
      latitude: -23.5000,
      longitude: -46.6000,
      type: PoiType.freeFlowToll,
      speedLimit: 80,
      direction: 0,
      roadName: 'Pórtico Entrada Trecho KM 10',
    );

    const endPoint = PoiPoint(
      id: 902,
      latitude: -23.4800,
      longitude: -46.6000,
      type: PoiType.freeFlowToll,
      speedLimit: 80,
      direction: 0,
      roadName: 'Pórtico Saída Trecho KM 12,2',
    );

    final testCorridor = AverageSpeedCorridor(
      id: 'corridor-sp099-km10-12',
      name: 'Trecho Monitorado KM 10 ao KM 12,2',
      startPoi: startPoint,
      endPoi: endPoint,
      lengthMeters: 2220.0,
      speedLimitKmh: 80.0,
    );

    late SectionControlMachine machine;

    setUp(() {
      machine = SectionControlMachine(corridors: [testCorridor]);
    });

    test('estado inicial da máquina deve ser inativo sem trecho ativo', () {
      expect(machine.state.isActive, isFalse);
      expect(machine.state.corridor, isNull);
      expect(machine.state.averageSpeedKmh, equals(0.0));
      expect(machine.state.distanceCoveredMeters, equals(0.0));
      expect(machine.state.isOverAverageSpeed, isFalse);
    });

    test('deve ativar o trecho ao aproximar e cruzar o ponto de entrada (Pórtico A)', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);

      // Coordenada a 20m do ponto de entrada rumo Norte (bearing 0°)
      final entryPos = VehiclePosition(
        latitude: -23.5002,
        longitude: -46.6000,
        speedKmh: 80.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      );

      machine.updatePosition(entryPos);

      expect(machine.state.isActive, isTrue);
      expect(machine.state.corridor?.id, equals('corridor-sp099-km10-12'));
      expect(machine.state.startTime, equals(t0));
      expect(machine.state.remainingMeters, closeTo(2220.0, 50.0));
    });

    test('deve calcular velocidade média em tempo real durante a travessia do trecho', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);

      // Entrada a 80 km/h
      machine.updatePosition(VehiclePosition(
        latitude: -23.5002,
        longitude: -46.6000,
        speedKmh: 80.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      ));

      expect(machine.state.isActive, isTrue);

      // Avança 1.000 metros em 36 segundos (100 km/h médio = 27.77 m/s * 36s = 1000m)
      final t1 = t0.add(const Duration(seconds: 36));
      machine.updatePosition(VehiclePosition(
        latitude: -23.4910,
        longitude: -46.6000,
        speedKmh: 100.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t1,
      ));

      expect(machine.state.isActive, isTrue);
      expect(machine.state.elapsedSeconds, equals(36));
      expect(machine.state.distanceCoveredMeters, greaterThan(900.0));
      // Velocidade média calculada deve ser aproximadamente 100 km/h
      expect(machine.state.averageSpeedKmh, closeTo(100.0, 5.0));
      // Como o limite é 80 km/h, deve marcar excesso de velocidade média!
      expect(machine.state.isOverAverageSpeed, isTrue);
      // Deve calcular tempo mínimo restante para não ser autuado
      expect(machine.state.targetRemainingSeconds, greaterThan(0));
    });

    test('deve concluir o trecho ao alcançar o ponto de saída (Pórtico B)', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);

      // Entrada
      machine.updatePosition(VehiclePosition(
        latitude: -23.5002,
        longitude: -46.6000,
        speedKmh: 80.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      ));

      // Chegada na saída (Pórtico B) a 2.220m após 100 segundos (velocidade média = 79.9 km/h)
      final tEnd = t0.add(const Duration(seconds: 100));
      final exitPos = VehiclePosition(
        latitude: -23.4800,
        longitude: -46.6000,
        speedKmh: 75.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: tEnd,
      );

      final result = machine.updatePosition(exitPos);

      expect(result, isNotNull);
      expect(result?.isCompleted, isTrue);
      expect(result?.corridorId, equals('corridor-sp099-km10-12'));
      expect(result?.averageSpeedKmh, closeTo(80.0, 5.0));
      expect(result?.isOverSpeed, isFalse);
      expect(machine.state.isActive, isFalse); // Trecho encerrado
    });

    test('deve resetar o trecho caso o condutor desvie da rota ou ocorra timeout (> 30 min)', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);

      // Entrada
      machine.updatePosition(VehiclePosition(
        latitude: -23.5002,
        longitude: -46.6000,
        speedKmh: 80.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      ));
      expect(machine.state.isActive, isTrue);

      // Posição 35 minutos depois longe da rota
      final tExpired = t0.add(const Duration(minutes: 35));
      machine.updatePosition(VehiclePosition(
        latitude: -23.9000,
        longitude: -46.9000,
        speedKmh: 80.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: tExpired,
      ));

      expect(machine.state.isActive, isFalse);
    });

    test('deve suportar copyWith e props de SectionControlState, Result e Corridor', () {
      final state1 = const SectionControlState();
      final state2 = state1.copyWith(
        isActive: true,
        averageSpeedKmh: 75.0,
        isOverAverageSpeed: true,
        remainingMeters: 1000.0,
        targetRemainingSeconds: 45,
      );

      expect(state2.isActive, isTrue);
      expect(state2.averageSpeedKmh, equals(75.0));
      expect(state2.isOverAverageSpeed, isTrue);
      expect(state2.remainingMeters, equals(1000.0));
      expect(state2.targetRemainingSeconds, equals(45));
      expect(state2.props.length, greaterThan(5));

      const result = SectionControlResult(
        corridorId: 'c1',
        isCompleted: true,
        averageSpeedKmh: 80.0,
        isOverSpeed: false,
        elapsedSeconds: 60,
        distanceMeters: 1500.0,
      );
      expect(result.props.length, equals(6));

      expect(testCorridor.props.length, equals(6));

      final constructedCorridor = AverageSpeedCorridor.fromCoordinates(
        id: 'test_from_coords',
        name: 'Trecho Coords',
        speedLimitKmh: 90,
        entryLatitude: -23.50,
        entryLongitude: -46.60,
        entryBearing: 180,
        exitLatitude: -23.48,
        exitLongitude: -46.60,
        exitBearing: 180,
      );
      expect(constructedCorridor.id, equals('test_from_coords'));
      expect(constructedCorridor.lengthMeters, greaterThan(1000));

      machine.reset();
      expect(machine.state.isActive, isFalse);
    });

    test('BUG #36 REGRESSÃO: jitter de GPS (< 3m) em velocidade zero não deve incrementar distância percorrida no trecho', () {
      final t0 = DateTime(2026, 10, 30, 10, 0, 0);

      // Entrada no trecho
      machine.updatePosition(VehiclePosition(
        latitude: -23.5002,
        longitude: -46.6000,
        speedKmh: 60.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      ));
      expect(machine.state.isActive, isTrue);

      // Condutor para no congestionamento (v = 0 km/h) após 500m
      final t1 = t0.add(const Duration(seconds: 20));
      machine.updatePosition(VehiclePosition(
        latitude: -23.4955,
        longitude: -46.6000,
        speedKmh: 0.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t1,
      ));

      final initialDistance = machine.state.distanceCoveredMeters;

      // 5 coordenadas consecutivas com jitter de ~1m e velocidade 0 km/h
      for (var i = 1; i <= 5; i++) {
        machine.updatePosition(VehiclePosition(
          latitude: -23.4955 + (0.000008 * (i % 2 == 0 ? 1 : -1)),
          longitude: -46.6000 + (0.000008 * (i % 3 == 0 ? 1 : -1)),
          speedKmh: 0.0,
          bearing: 0.0,
          accuracyMeters: 5.0,
          timestamp: t1.add(Duration(seconds: i)),
        ));
      }

      // Distância percorrida não deve ter sofrido deslocamento fantasma
      expect(machine.state.distanceCoveredMeters, equals(initialDistance));
    });
  });
}