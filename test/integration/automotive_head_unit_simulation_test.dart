import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/automotive/automotive_service.dart';
import 'package:sentinela/core/automotive/car_app_models.dart';
import 'package:sentinela/core/automotive/car_app_platform_interface.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Simulação de Integração Hermética: Central Multimídia Automotiva (Android Auto & CarPlay)', () {
    late Database db;
    late DatabaseManager dbManager;
    late PoiRepository repository;
    late AlertMachine alertMachine;
    late FakeCarAppPlatform fakeCarPlatform;
    late AutomotiveService automotiveService;
    late DashboardCubit cubit;

    setUp(() {
      db = sqlite3.openInMemory();
      dbManager = DatabaseManager(db);
      dbManager.initializeSchema();
      repository = PoiRepository(dbManager);

      // Cadastra radar fixo na Av. Paulista (limite 50 km/h)
      repository.savePoi(
        const PoiPoint(
          id: 101,
          type: PoiType.fixedRadar,
          latitude: -23.5615,
          longitude: -46.6559,
          speedLimit: 50,
          direction: 135,
          roadName: 'Av. Paulista',
        ),
      );

      alertMachine = AlertMachine();
      fakeCarPlatform = FakeCarAppPlatform();
      automotiveService = AutomotiveService(platform: fakeCarPlatform);

      cubit = DashboardCubit(
        repository: repository,
        alertMachine: alertMachine,
        automotiveService: automotiveService,
      );
    });

    tearDown(() async {
      await cubit.close();
      automotiveService.dispose();
      db.close();
    });

    test('Simula conexão veicular, condução com excesso de velocidade e envio para display do carro', () async {
      // 1. Veículo conecta ao Android Auto
      fakeCarPlatform.setSimulatedConnectionStatus(CarConnectionStatus.connectedAndroidAuto);
      await pumpEventQueue();

      expect(automotiveService.isConnected, isTrue);
      expect(fakeCarPlatform.isSessionActive, isTrue);

      // 2. Veículo se aproxima da Av. Paulista a 65 km/h (excesso de velocidade sobre 50 km/h)
      final pos1 = VehiclePosition(
        latitude: -23.5600,
        longitude: -46.6570,
        speedKmh: 65.0,
        bearing: 135.0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 31, 10, 0, 0),
      );

      await cubit.onLocationUpdated(pos1);
      await pumpEventQueue();

      final display1 = fakeCarPlatform.lastData;
      expect(display1, isNotNull);
      expect(display1!.currentSpeedKmh, 65.0);
      expect(display1.speedLimitKmh, 50);
      expect(display1.roadName, 'Av. Paulista');
      expect(display1.isOverSpeed, isTrue);
      expect(display1.connectionStatus, CarConnectionStatus.connectedAndroidAuto);

      // 3. Condutor toca no botão da central do carro para reportar radar móvel avistado
      fakeCarPlatform.simulateCarAction(CarAction.quickReportRadar);
      await pumpEventQueue();

      // 4. Veículo desacelera para 45 km/h e cruza o radar com segurança
      final pos2 = VehiclePosition(
        latitude: -23.5615,
        longitude: -46.6559,
        speedKmh: 45.0,
        bearing: 135.0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 31, 10, 0, 10),
      );

      await cubit.onLocationUpdated(pos2);
      await pumpEventQueue();

      final display2 = fakeCarPlatform.lastData;
      expect(display2, isNotNull);
      expect(display2!.currentSpeedKmh, 45.0);
      expect(display2.isOverSpeed, isFalse);

      // 5. Condutor desliga o carro e desconecta o cabo USB/CarPlay
      fakeCarPlatform.setSimulatedConnectionStatus(CarConnectionStatus.disconnected);
      await pumpEventQueue();

      expect(automotiveService.isConnected, isFalse);
      expect(fakeCarPlatform.isSessionActive, isFalse);
    });
  });
}
