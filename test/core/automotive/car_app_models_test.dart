import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/automotive/car_app_models.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('CarAppModels (BDD - Modelos para Android Auto & Apple CarPlay)', () {
    test('CarConnectionStatus enum deve conter status válidos e getters auxiliares', () {
      expect(CarConnectionStatus.disconnected.isConnected, isFalse);
      expect(CarConnectionStatus.connecting.isConnected, isFalse);
      expect(CarConnectionStatus.connectedAndroidAuto.isConnected, isTrue);
      expect(CarConnectionStatus.connectedCarPlay.isConnected, isTrue);

      expect(CarConnectionStatus.connectedAndroidAuto.displayName, 'Android Auto');
      expect(CarConnectionStatus.connectedCarPlay.displayName, 'Apple CarPlay');
      expect(CarConnectionStatus.disconnected.displayName, 'Desconectado');
    });

    test('CarDistractionLevel enum deve mapear regras de distração veicular', () {
      expect(CarDistractionLevel.parked.maxAllowedActions, 6);
      expect(CarDistractionLevel.driving.maxAllowedActions, 4);
      expect(CarDistractionLevel.highSpeed.maxAllowedActions, 2);
    });

    test('CarSonarItem deve suportar serialização e igualdade por valor', () {
      const item = CarSonarItem(
        label: 'Radar 60 km/h',
        distanceMeters: 250,
        relativeAngleDeg: -15,
        poiType: PoiType.fixedRadar,
        isCritical: false,
      );

      final map = item.toMap();
      expect(map['label'], 'Radar 60 km/h');
      expect(map['distanceMeters'], 250);
      expect(map['poiType'], 'fixedRadar');

      final reconstructed = CarSonarItem.fromMap(map);
      expect(reconstructed, equals(item));
    });

    test('CarAppData deve serializar dados completos para canal nativo de tela automotiva', () {
      const activeAlert = ActiveAlert(
        poi: PoiPoint(id: 10, latitude: -23.55, longitude: -46.63, type: PoiType.fixedRadar, speedLimit: 70),
        distanceMeters: 320,
        currentSpeedKmh: 80,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 90,
        relativeBearing: 0,
      );

      const data = CarAppData(
        currentSpeedKmh: 80.0,
        speedLimitKmh: 70,
        roadName: 'Av. 23 de Maio',
        alertStatus: AlertStatus.overSpeed,
        activeAlert: activeAlert,
        connectionStatus: CarConnectionStatus.connectedAndroidAuto,
        isMuted: false,
        isNightMode: true,
        distractionLevel: CarDistractionLevel.driving,
        simplifiedSonarItems: [
          CarSonarItem(
            label: 'Radar 70',
            distanceMeters: 320,
            relativeAngleDeg: 0,
            poiType: PoiType.fixedRadar,
            isCritical: true,
          ),
        ],
        allowedActions: [
          CarAction.quickReportRadar,
          CarAction.toggleMute,
        ],
      );

      final map = data.toMap();
      expect(map['currentSpeedKmh'], 80.0);
      expect(map['speedLimitKmh'], 70);
      expect(map['roadName'], 'Av. 23 de Maio');
      expect(map['alertStatus'], 'overSpeed');
      expect(map['isOverSpeed'], isTrue);
      expect(map['connectionStatus'], 'connectedAndroidAuto');
      expect(map['isNightMode'], isTrue);
      expect((map['simplifiedSonarItems'] as List).length, 1);
      expect((map['allowedActions'] as List).length, 2);

      final reconstructed = CarAppData.fromMap(map);
      expect(reconstructed.currentSpeedKmh, 80.0);
      expect(reconstructed.speedLimitKmh, 70);
      expect(reconstructed.roadName, 'Av. 23 de Maio');
      expect(reconstructed.alertStatus, AlertStatus.overSpeed);
      expect(reconstructed.connectionStatus, CarConnectionStatus.connectedAndroidAuto);
      expect(reconstructed.allowedActions, contains(CarAction.quickReportRadar));
      expect(reconstructed.allowedActions, contains(CarAction.toggleMute));
    });

    test('CarAppData copyWith deve permitir atualizações parciais imutáveis', () {
      const initial = CarAppData(
        currentSpeedKmh: 50.0,
        connectionStatus: CarConnectionStatus.connectedCarPlay,
      );

      final updated = initial.copyWith(
        currentSpeedKmh: 55.0,
        speedLimitKmh: 60,
        isMuted: true,
      );

      expect(updated.currentSpeedKmh, 55.0);
      expect(updated.speedLimitKmh, 60);
      expect(updated.isMuted, isTrue);
      expect(updated.connectionStatus, CarConnectionStatus.connectedCarPlay);
    });

    test('CarAppData deve suportar igualdade Equatable e fallback para valores desconhecidos', () {
      const data1 = CarAppData(
        currentSpeedKmh: 40.0,
        roadName: 'Rua A',
      );
      const data2 = CarAppData(
        currentSpeedKmh: 40.0,
        roadName: 'Rua A',
      );
      expect(data1, equals(data2));
      expect(data1.props, equals(data2.props));

      // Teste de fallback orElse em fromMap
      final fallbackData = CarAppData.fromMap({
        'alertStatus': 'unknown_status',
        'connectionStatus': 'unknown_conn',
        'distractionLevel': 'unknown_level',
        'allowedActions': <String>[],
      });
      expect(fallbackData.alertStatus, AlertStatus.idle);
      expect(fallbackData.connectionStatus, CarConnectionStatus.disconnected);
      expect(fallbackData.distractionLevel, CarDistractionLevel.parked);
      expect(fallbackData.allowedActions.length, 2);

      // CarAction fallback
      expect(CarAction.fromName('unknownAction'), CarAction.quickReportRadar);
    });
  });
}
