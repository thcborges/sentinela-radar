import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/engine/poi_cluster_engine.dart';
import 'package:sentinela/core/geo/dead_reckoning_engine.dart';
import 'package:sentinela/core/geo/haversine.dart';
import 'package:sentinela/core/geo/solar_calculator.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/models/vehicle_profile.dart';

void main() {
  group('Simulação de Integração Hermética: Travessia de Túnel com Dead Reckoning, Perfil Pesado e Cluster de POIs', () {
    late DeadReckoningEngine deadReckoning;
    late PoiClusterEngine clusterEngine;
    late AlertMachine alertMachine;

    setUp(() {
      deadReckoning = DeadReckoningEngine();
      clusterEngine = const PoiClusterEngine(clusterRadiusMeters: 45.0);
      alertMachine = AlertMachine(
        preferences: const AlertPreferences(anticipationTimeSeconds: 12.0),
        vehicleProfile: VehicleProfile.heavy(), // Veículo Pesado: fator 1.40x e teto 90 km/h (Art. 61 CTB)
      );
    });

    test('Veículo pesado entra em túnel rodoviário, perde GPS, detecta radar interno via inércia e recupera sinal na saída', () {
      // Cenário: Rodovia dos Imigrantes (SP-160), descida da serra em direção ao litoral.
      // Rumo Sul (~180° bearing).
      // Túnel inicia em lat: -23.9000, lon: -46.5000.
      // Radar Fixo interno no túnel: lat: -23.9040, lon: -46.5000, limite 60 km/h, rumo 180°.
      // Câmera de sinal/faixa acoplada próxima (cluster a 20m): lat: -23.90415, lon: -46.5000.
      final poiRadar = PoiPoint(
        id: 101,
        latitude: -23.9040,
        longitude: -46.5000,
        type: PoiType.fixedRadar,
        speedLimit: 60,
        direction: 180,
      );

      final poiFaixa = PoiPoint(
        id: 102,
        latitude: -23.90415,
        longitude: -46.5000,
        type: PoiType.redLightCamera,
        direction: 180,
      );

      // 1. Clusterização espacial dos pontos no túnel
      final clusters = clusterEngine.clusterPois([poiRadar, poiFaixa]);
      expect(clusters.length, equals(1));
      expect(clusters.first.isMultiPoint, isTrue);
      expect(clusters.first.primaryPoi.id, equals(101));
      expect(clusters.first.compositeTtsPhrase, contains('Radar fixo, 60 km/h'));
      expect(clusters.first.compositeTtsPhrase, contains('sinal vermelho'));

      var currentTime = DateTime.utc(2026, 10, 30, 14, 0, 0); // 14:00 UTC (11:00 BRT)

      // 2. Veículo pesado viajando a 80 km/h com rumo 180° antes de entrar no túnel
      final p1 = VehiclePosition(
        latitude: -23.8950,
        longitude: -46.5000,
        speedKmh: 80.0,
        bearing: 180.0,
        accuracyMeters: 4.0,
        timestamp: currentTime,
      );

      final accepted = deadReckoning.updateWithGps(p1);
      expect(accepted, isTrue);
      expect(deadReckoning.status, equals(DeadReckoningStatus.gpsLocked));

      // Atualiza máquina de alertas com o radar primário do cluster
      alertMachine.updatePosition(p1, [poiRadar]);
      // Distância ~1000m: deve estar IDLE fora da antecipação
      final distP1 = haversineDistance(p1.latitude, p1.longitude, poiRadar.latitude, poiRadar.longitude);
      expect(distP1, greaterThan(800.0));
      expect(alertMachine.state.status, equals(AlertStatus.idle));

      // 3. Veículo entra no túnel em t + 10s: GPS degrada para 65m de precisão
      currentTime = currentTime.add(const Duration(seconds: 10));
      final pDegraded = VehiclePosition(
        latitude: -23.8972,
        longitude: -46.5000,
        speedKmh: 75.0,
        bearing: 180.0,
        accuracyMeters: 65.0, // Degradado (> 40m)
        timestamp: currentTime,
      );

      final degradedAccepted = deadReckoning.updateWithGps(pDegraded);
      expect(degradedAccepted, isFalse);
      expect(deadReckoning.status, equals(DeadReckoningStatus.deadReckoning));

      // 4. Perda total de sinal GPS dentro do túnel por 15 segundos
      // O sistema executa projeções inerciais (Dead Reckoning) a cada 1 segundo
      VehiclePosition? currentProjected;
      for (int i = 1; i <= 15; i++) {
        currentTime = currentTime.add(const Duration(seconds: 1));
        currentProjected = deadReckoning.projectPosition(currentTime);
        expect(deadReckoning.status, equals(DeadReckoningStatus.deadReckoning));

        if (currentProjected != null) {
          alertMachine.updatePosition(currentProjected, [poiRadar], isDeadReckoning: true);
        }
      }

      // Verificação após 15s de Dead Reckoning:
      expect(currentProjected, isNotNull);
      // O veículo desceu em direção ao Sul (lat diminuindo para mais negativo que -23.8972)
      expect(currentProjected!.latitude, lessThan(-23.8972));
      expect(currentProjected.speedKmh, closeTo(75.0, 5.0)); // Amortecimento suave

      // 5. Veículo avança mais 10 segundos no túnel e entra na zona de alerta do radar interno (60 km/h)
      // Como o veículo está a ~70 km/h e o radar é 60 km/h, deve disparar OVER_SPEED
      for (int i = 1; i <= 10; i++) {
        currentTime = currentTime.add(const Duration(seconds: 1));
        currentProjected = deadReckoning.projectPosition(currentTime);
        if (currentProjected != null) {
          alertMachine.updatePosition(currentProjected, [poiRadar], isDeadReckoning: true);
        }
      }

      // Distância ao radar deve estar dentro da antecipação do caminhão
      // Antecipação para caminhão a 70 km/h (19.4 m/s): 19.4 * 12s * 1.40 = 326m
      expect(alertMachine.state.activeAlert, isNotNull);
      expect(alertMachine.state.status, anyOf(AlertStatus.alerting, AlertStatus.overSpeed));
      expect(alertMachine.state.activeAlert!.isOverSpeed, isTrue); // 70 km/h > 60 km/h
      expect(alertMachine.state.activeAlert!.poi.speedLimit, equals(60));

      // 6. Condutor reduz a velocidade dentro do túnel para 55 km/h
      deadReckoning.calibrateSensorVelocity(speedKmh: 55.0, bearing: 180.0);
      currentTime = currentTime.add(const Duration(seconds: 2));
      currentProjected = deadReckoning.projectPosition(currentTime);
      expect(currentProjected, isNotNull);
      alertMachine.updatePosition(currentProjected!, [poiRadar], isDeadReckoning: true);

      expect(alertMachine.state.activeAlert!.isOverSpeed, isFalse); // 55 km/h <= 60 km/h

      // 7. Veículo passa pelo radar e continua mais 15 segundos
      for (int i = 1; i <= 15; i++) {
        currentTime = currentTime.add(const Duration(seconds: 1));
        currentProjected = deadReckoning.projectPosition(currentTime);
        if (currentProjected != null) {
          alertMachine.updatePosition(currentProjected, [poiRadar], isDeadReckoning: true);
        }
      }

      // 8. Veículo sai do túnel: GPS fix restabelecido com 3.2m de precisão
      currentTime = currentTime.add(const Duration(seconds: 1));
      final pRecovered = VehiclePosition(
        latitude: -23.9080,
        longitude: -46.5000,
        speedKmh: 60.0,
        bearing: 180.0,
        accuracyMeters: 3.2,
        timestamp: currentTime,
      );

      final recoveredAccepted = deadReckoning.updateWithGps(pRecovered);
      expect(recoveredAccepted, isTrue);
      expect(deadReckoning.status, equals(DeadReckoningStatus.gpsLocked));
      expect(deadReckoning.lastKnownPosition!.latitude, equals(pRecovered.latitude));
      expect(deadReckoning.lastKnownPosition!.accuracyMeters, equals(3.2));

      // 9. Validação do cálculo solar crepuscular para o túnel / local
      // Às 14:00 UTC (11:00 local em SP), o sol está alto (isDaytime = true)
      final isDay = SolarCalculator.isDaytime(
        latitude: pRecovered.latitude,
        longitude: pRecovered.longitude,
        time: currentTime,
      );
      expect(isDay, isTrue);

      // Mas se estivesse em HudThemeMode.tunnelOrNight, ou à meia-noite (03:00 UTC), seria noite
      final isNightAtMidnight = SolarCalculator.isDaytime(
        latitude: pRecovered.latitude,
        longitude: pRecovered.longitude,
        time: DateTime.utc(2026, 10, 30, 3, 0, 0),
      );
      expect(isNightAtMidnight, isFalse);
    });
  });
}
