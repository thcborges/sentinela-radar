import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/geo/dead_reckoning_engine.dart';
import 'package:sentinela/core/geo/haversine.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('DeadReckoningEngine (Navegação Inercial em Túneis e Falha de GPS)', () {
    late DeadReckoningEngine engine;

    setUp(() {
      engine = DeadReckoningEngine(
        gpsLossTimeoutSeconds: 2.0,
        maxAcceptableAccuracyMeters: 40.0,
        maxDeadReckoningDurationSeconds: 180.0,
        speedDampingPerSecond: 0.99,
      );
    });

    test('deve inicializar no estado searchingSignal quando ainda não recebeu GPS', () {
      expect(engine.status, equals(DeadReckoningStatus.searchingSignal));
      expect(engine.isDeadReckoningActive, isFalse);
      expect(engine.lastKnownPosition, isNull);
    });

    test('deve transicionar para gpsLocked ao receber posição com boa acurácia', () {
      final initialTime = DateTime(2026, 10, 30, 12, 0, 0);
      final pos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 72.0,
        bearing: 0.0, // Rumo Norte
        accuracyMeters: 10.0,
        timestamp: initialTime,
      );

      engine.updateWithGps(pos);

      expect(engine.status, equals(DeadReckoningStatus.gpsLocked));
      expect(engine.isDeadReckoningActive, isFalse);
      expect(engine.lastKnownPosition, equals(pos));
    });

    test('deve rejeitar GPS com precisão degradada (>40m) e transicionar para deadReckoning se já estava em movimento', () {
      final initialTime = DateTime(2026, 10, 30, 12, 0, 0);
      final goodPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 72.0,
        bearing: 0.0,
        accuracyMeters: 10.0,
        timestamp: initialTime,
      );

      engine.updateWithGps(goodPos);

      // Sinal degradado típico da entrada de um túnel
      final degradedPos = VehiclePosition(
        latitude: -23.5510,
        longitude: -46.6340,
        speedKmh: 70.0,
        bearing: 0.0,
        accuracyMeters: 85.0, // Impreciso!
        timestamp: initialTime.add(const Duration(seconds: 1)),
      );

      final accepted = engine.updateWithGps(degradedPos);

      expect(accepted, isFalse);
      expect(engine.status, equals(DeadReckoningStatus.deadReckoning));
      expect(engine.isDeadReckoningActive, isTrue);
    });

    test('deve projetar a posição cinemática para o Norte com precisão em intervalo de 5s', () {
      final t0 = DateTime(2026, 10, 30, 12, 0, 0);
      final initialPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 72.0, // 20 m/s
        bearing: 0.0, // Rumo Norte
        accuracyMeters: 8.0,
        timestamp: t0,
      );

      engine.updateWithGps(initialPos);

      // Simula 5 segundos decorridos dentro do túnel sem GPS
      final t5 = t0.add(const Duration(seconds: 5));
      final projected = engine.projectPosition(t5);

      expect(projected, isNotNull);
      expect(engine.status, equals(DeadReckoningStatus.deadReckoning));
      expect(engine.isDeadReckoningActive, isTrue);

      // A 20 m/s por 5s, o veículo deve ter percorrido aproximadamente 100m para o Norte
      final distanceTraveled = haversineDistance(
        initialPos.latitude,
        initialPos.longitude,
        projected!.latitude,
        projected.longitude,
      );

      expect(distanceTraveled, greaterThanOrEqualTo(95.0));
      expect(distanceTraveled, lessThanOrEqualTo(105.0));
      expect(projected.latitude, greaterThan(initialPos.latitude)); // Foi para o Norte
      expect(projected.bearing, equals(0.0));
      expect(projected.accuracyMeters, greaterThanOrEqualTo(15.0)); // Incerteza aumenta com o tempo
    });

    test('deve projetar posição para o Leste (bearing 90°)', () {
      final t0 = DateTime(2026, 10, 30, 12, 0, 0);
      final initialPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 90.0, // 25 m/s
        bearing: 90.0, // Leste
        accuracyMeters: 5.0,
        timestamp: t0,
      );

      engine.updateWithGps(initialPos);

      // 4 segundos a 25 m/s = 100 metros para o Leste
      final t4 = t0.add(const Duration(seconds: 4));
      final projected = engine.projectPosition(t4);

      expect(projected, isNotNull);
      expect(projected!.longitude, greaterThan(initialPos.longitude)); // Mais a Leste
      final distance = haversineDistance(
        initialPos.latitude,
        initialPos.longitude,
        projected.latitude,
        projected.longitude,
      );
      expect(distance, inInclusiveRange(95.0, 105.0));
    });

    test('deve aplicar desaceleração suave (damping) na velocidade projetada', () {
      final t0 = DateTime(2026, 10, 30, 12, 0, 0);
      final initialPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 100.0,
        bearing: 45.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      );

      engine.updateWithGps(initialPos);

      final t10 = t0.add(const Duration(seconds: 10));
      final projected = engine.projectPosition(t10);

      expect(projected, isNotNull);
      // Com speedDampingPerSecond = 0.99, a velocidade após 10s deve ser menor que 100 km/h
      expect(projected!.speedKmh, lessThan(100.0));
      expect(projected.speedKmh, greaterThan(85.0));
    });

    test('deve transicionar para searchingSignal se o tempo de túnel exceder o limite máximo', () {
      final t0 = DateTime(2026, 10, 30, 12, 0, 0);
      final initialPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 60.0,
        bearing: 180.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      );

      engine.updateWithGps(initialPos);

      // Tempo superior a maxDeadReckoningDurationSeconds (180s = 3 minutos)
      final tExpired = t0.add(const Duration(seconds: 185));
      final projected = engine.projectPosition(tExpired);

      expect(projected, isNull);
      expect(engine.status, equals(DeadReckoningStatus.searchingSignal));
      expect(engine.isDeadReckoningActive, isFalse);
    });

    test('deve retornar para gpsLocked com sucesso ao sair do túnel e recuperar GPS', () {
      final t0 = DateTime(2026, 10, 30, 12, 0, 0);
      engine.updateWithGps(VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 80.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      ));

      // Entra em dead reckoning
      engine.projectPosition(t0.add(const Duration(seconds: 5)));
      expect(engine.status, equals(DeadReckoningStatus.deadReckoning));

      // Recupera GPS na saída do túnel com boa acurácia
      final recoveredPos = VehiclePosition(
        latitude: -23.5480,
        longitude: -46.6333,
        speedKmh: 75.0,
        bearing: 0.0,
        accuracyMeters: 12.0,
        timestamp: t0.add(const Duration(seconds: 15)),
      );

      final accepted = engine.updateWithGps(recoveredPos);

      expect(accepted, isTrue);
      expect(engine.status, equals(DeadReckoningStatus.gpsLocked));
      expect(engine.isDeadReckoningActive, isFalse);
      expect(engine.lastKnownPosition, equals(recoveredPos));
    });

    test('deve emitir eventos de status na stream reativa e suportar reset', () async {
      final List<DeadReckoningStatus> emittedStatuses = [];
      final sub = engine.statusStream.listen(emittedStatuses.add);

      final t0 = DateTime(2026, 10, 30, 12, 0, 0);
      engine.updateWithGps(VehiclePosition(
        latitude: -23.0,
        longitude: -46.0,
        speedKmh: 50.0,
        bearing: 0.0,
        accuracyMeters: 10.0,
        timestamp: t0,
      ));

      engine.projectPosition(t0.add(const Duration(seconds: 5)));
      engine.reset();

      await pumpEventQueue();

      expect(emittedStatuses, contains(DeadReckoningStatus.gpsLocked));
      expect(emittedStatuses, contains(DeadReckoningStatus.deadReckoning));
      expect(emittedStatuses, contains(DeadReckoningStatus.searchingSignal));
      expect(engine.lastKnownPosition, isNull);

      await sub.cancel();
      engine.dispose();
    });
  });
}
