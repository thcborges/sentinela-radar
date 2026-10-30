import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/platform/live_activity_service.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}

void main() {
  late MockPoiRepository mockRepo;
  late MockAlertMachine mockAlertMachine;
  late DashboardCubit cubit;

  setUp(() {
    mockRepo = MockPoiRepository();
    mockAlertMachine = MockAlertMachine();
    when(() => mockAlertMachine.state).thenReturn(const AlertState(status: AlertStatus.idle));
    cubit = DashboardCubit(
      repository: mockRepo,
      alertMachine: mockAlertMachine,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('DashboardCubit & State', () {
    test('Estado inicial deve ter velocidade zero, GPS inativo e todos os tipos habilitados', () {
      final state = cubit.state;
      expect(state.currentSpeedKmh, equals(0.0));
      expect(state.currentBearing, equals(0.0));
      expect(state.alertStatus, equals(AlertStatus.idle));
      expect(state.activeAlert, isNull);
      expect(state.isGpsFixValid, isFalse);
      expect(state.nearbySonarPois, isEmpty);
      expect(state.enabledPoiTypes.length, equals(PoiType.values.length));
    });

    test('onLocationUpdated com GPS inválido (precisão > 35m) deve marcar isGpsFixValid como false', () async {
      final badPosition = VehiclePosition(
        latitude: -23.55,
        longitude: -46.63,
        speedKmh: 60.0,
        bearing: 90.0,
        accuracyMeters: 50.0,
        timestamp: DateTime(2026, 10, 30, 10, 0),
      );

      await cubit.onLocationUpdated(badPosition);

      expect(cubit.state.isGpsFixValid, isFalse);
      expect(cubit.state.currentSpeedKmh, equals(60.0));
      verifyNever(() => mockRepo.findNearbyPois(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusMeters: any(named: 'radiusMeters'),
      ));
    });

    test('onLocationUpdated com GPS válido deve consultar repositório e atualizar sonar e alertas', () async {
      final goodPosition = VehiclePosition(
        latitude: -23.5500,
        longitude: -46.6300,
        speedKmh: 72.0,
        bearing: 0.0, // Rumo Norte
        accuracyMeters: 5.0,
        timestamp: DateTime(2026, 10, 30, 10, 0),
      );

      const candidatePoi = PoiPoint(
        id: 1,
        latitude: -23.5450, // Ponto ao Norte
        longitude: -46.6300,
        type: PoiType.fixedRadar,
        speedLimit: 60,
        roadName: 'Av. Brasil',
        direction: 0,
      );

      when(() => mockRepo.findNearbyPois(
        latitude: -23.5500,
        longitude: -46.6300,
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => [candidatePoi]);

      const activeAlert = ActiveAlert(
        poi: candidatePoi,
        distanceMeters: 300,
        currentSpeedKmh: 72,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 0.0,
        relativeBearing: 0.0,
      );

      when(() => mockAlertMachine.updatePosition(goodPosition, any()))
          .thenReturn(null);
      when(() => mockAlertMachine.state).thenReturn(const AlertState(
        status: AlertStatus.overSpeed,
        activeAlert: activeAlert,
      ));

      await cubit.onLocationUpdated(goodPosition);

      expect(cubit.state.isGpsFixValid, isTrue);
      expect(cubit.state.currentSpeedKmh, equals(72.0));
      expect(cubit.state.currentBearing, equals(0.0));
      expect(cubit.state.activeAlert, equals(activeAlert));
      expect(cubit.state.alertStatus, equals(AlertStatus.overSpeed));
      expect(cubit.state.nearbySonarPois.length, equals(1));
      expect(cubit.state.nearbySonarPois.first.poi, equals(candidatePoi));
      expect(cubit.state.roadName, equals('Av. Brasil'));
    });

    test('togglePoiType deve adicionar ou remover tipo de POI dos filtros', () {
      expect(cubit.state.enabledPoiTypes.contains(PoiType.physicalSpeedBump), isTrue);

      cubit.togglePoiType(PoiType.physicalSpeedBump, false);
      expect(cubit.state.enabledPoiTypes.contains(PoiType.physicalSpeedBump), isFalse);

      cubit.togglePoiType(PoiType.physicalSpeedBump, true);
      expect(cubit.state.enabledPoiTypes.contains(PoiType.physicalSpeedBump), isTrue);
    });

    test('deve alternar modo espelho HUD para para-brisa via toggleHudMirrorMode e setHudMirrorMode', () {
      expect(cubit.state.isHudMirrorMode, isFalse);

      cubit.toggleHudMirrorMode();
      expect(cubit.state.isHudMirrorMode, isTrue);

      cubit.toggleHudMirrorMode();
      expect(cubit.state.isHudMirrorMode, isFalse);

      cubit.setHudMirrorMode(true);
      expect(cubit.state.isHudMirrorMode, isTrue);

      cubit.setHudMirrorMode(false);
      expect(cubit.state.isHudMirrorMode, isFalse);
    });

    test('setInitialPoiCount deve atualizar contagem total no estado', () {
      cubit.setInitialPoiCount(74820);
      expect(cubit.state.totalPoisCount, equals(74820));
    });

    test('alertMachine getter deve retornar a instancia correta', () {
      expect(cubit.alertMachine, equals(mockAlertMachine));
    });

    test('onLocationUpdated e close devem atualizar e parar LiveActivityService quando fornecido', () async {
      final fakePlatform = FakeLiveActivityPlatform(supported: true);
      final liveService = LiveActivityService(platform: fakePlatform);

      final liveCubit = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
        liveActivityService: liveService,
      );

      final goodPosition = VehiclePosition(
        latitude: -23.5500,
        longitude: -46.6300,
        speedKmh: 80.0,
        bearing: 90.0,
        accuracyMeters: 5.0,
        timestamp: DateTime(2026, 10, 30, 10, 0),
      );

      const candidatePoi = PoiPoint(
        id: 99,
        latitude: -23.5500,
        longitude: -46.6200,
        type: PoiType.fixedRadar,
        speedLimit: 70,
        roadName: 'Rod. dos Bandeirantes',
      );

      when(() => mockRepo.findNearbyPois(
        latitude: -23.5500,
        longitude: -46.6300,
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => [candidatePoi]);

      const activeAlert = ActiveAlert(
        poi: candidatePoi,
        distanceMeters: 250,
        currentSpeedKmh: 80,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 90.0,
        relativeBearing: 0.0,
      );

      when(() => mockAlertMachine.updatePosition(goodPosition, any())).thenReturn(null);
      when(() => mockAlertMachine.state).thenReturn(const AlertState(
        status: AlertStatus.overSpeed,
        activeAlert: activeAlert,
      ));

      await liveCubit.onLocationUpdated(goodPosition);

      expect(liveService.isActive, isTrue);
      expect(liveService.currentData?.currentSpeedKmh, equals(80.0));
      expect(liveService.currentData?.speedLimitKmh, equals(70));
      expect(liveService.currentData?.alertStatus, equals(AlertStatus.overSpeed));
      expect(liveService.currentData?.isAlertActive, isTrue);

      await liveCubit.close();
      expect(liveService.isActive, isFalse);
    });
  });
}
