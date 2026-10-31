import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/poi_cluster_engine.dart';
import 'package:sentinela/core/engine/section_control_machine.dart';
import 'package:sentinela/core/geo/dead_reckoning_engine.dart';
import 'package:sentinela/core/geo/solar_calculator.dart';
import 'package:sentinela/core/l10n/app_language.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/models/vehicle_profile.dart';
import 'package:sentinela/core/platform/haptic_feedback_engine.dart';
import 'package:sentinela/core/platform/live_activity_service.dart';
import 'package:sentinela/data/repository/custom_poi_repository.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sqlite3/sqlite3.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('deve atualizar e resetar SectionControlMachine quando configurado', () async {
      final corridor = AverageSpeedCorridor.fromCoordinates(
        id: 'test_corridor',
        name: 'Trecho Teste SP',
        speedLimitKmh: 80,
        entryLatitude: -23.5500,
        entryLongitude: -46.6300,
        entryBearing: 0.0,
        exitLatitude: -23.5400,
        exitLongitude: -46.6300,
        exitBearing: 0.0,
      );
      final sectionMachine = SectionControlMachine(corridors: [corridor]);
      final cubitWithSection = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
        sectionControlMachine: sectionMachine,
      );

      when(() => mockRepo.findNearbyPois(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => []);

      final entryPos = VehiclePosition(
        latitude: -23.5501,
        longitude: -46.6300,
        speedKmh: 80.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime(2026, 10, 30, 10, 0, 0),
      );

      await cubitWithSection.onLocationUpdated(entryPos);
      expect(cubitWithSection.state.sectionControlState.isActive, isTrue);

      cubitWithSection.resetSectionControl();
      expect(cubitWithSection.state.sectionControlState.isActive, isFalse);

      await cubitWithSection.close();
    });

    test('reportQuickPoi deve persistir ponto customizado e atualizar contagem e sonar', () async {
      final db = sqlite3.openInMemory();
      final customRepo = CustomPoiRepository(db);
      customRepo.initializeSchema();

      final cubitWithCustom = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
        customPoiRepository: customRepo,
      );

      when(() => mockRepo.findNearbyPois(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => []);

      // Sem posição GPS, não deve registrar
      final nullReport = await cubitWithCustom.reportQuickPoi(type: PoiType.mobileRadar);
      expect(nullReport, isNull);

      final currentPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 60.0,
        bearing: 90.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 10, 0, 0),
      );

      await cubitWithCustom.onLocationUpdated(currentPos);

      final saved = await cubitWithCustom.reportQuickPoi(
        type: PoiType.mobileRadar,
        speedLimit: 60,
        description: 'Viatura avistada no acostamento',
      );

      expect(saved, isNotNull);
      expect(saved!.type, PoiType.mobileRadar);
      expect(saved.latitude, -23.5505);
      expect(saved.longitude, -46.6333);
      expect(saved.speedLimit, 60);
      expect(saved.direction, 90);
      expect(cubitWithCustom.state.userPoiCount, 1);

      await cubitWithCustom.close();
      db.close();
    });

    test('deve atualizar perfil veicular via setVehicleProfile', () {
      expect(cubit.state.vehicleProfile.type, equals(VehicleType.car));

      cubit.setVehicleProfile(VehicleProfile.heavy());

      expect(cubit.state.vehicleProfile.type, equals(VehicleType.heavy));
      verify(() => mockAlertMachine.updateVehicleProfile(VehicleProfile.heavy())).called(1);
    });

    test('deve alternar modo de tema visual via setHudThemeMode e resolver tema efetivo', () {
      expect(cubit.state.hudThemeMode, equals(HudThemeMode.darkOnly));
      expect(cubit.state.isEffectiveThemeDark, isTrue);

      cubit.setHudThemeMode(HudThemeMode.dayHighContrast);
      expect(cubit.state.hudThemeMode, equals(HudThemeMode.dayHighContrast));
      // Não estando em túnel, modo diurno tem isEffectiveThemeDark = false
      expect(cubit.state.isEffectiveThemeDark, isFalse);
    });

    test('deve projetar navegação inercial em túnel via tickDeadReckoning', () async {
      final drEngine = DeadReckoningEngine();
      final cubitWithDr = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
        deadReckoningEngine: drEngine,
      );

      when(() => mockRepo.findNearbyPois(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => []);

      final t0 = DateTime(2026, 10, 30, 12, 0, 0);
      final initialPos = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 80.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      );

      await cubitWithDr.onLocationUpdated(initialPos);
      expect(cubitWithDr.state.deadReckoningStatus, equals(DeadReckoningStatus.gpsLocked));
      expect(cubitWithDr.state.isTunnelMode, isFalse);

      // Simula 3 segundos sem GPS dentro do túnel
      final t3 = t0.add(const Duration(seconds: 3));
      final projected = await cubitWithDr.tickDeadReckoning(t3);

      expect(projected, isNotNull);
      expect(cubitWithDr.state.deadReckoningStatus, equals(DeadReckoningStatus.deadReckoning));
      expect(cubitWithDr.state.isTunnelMode, isTrue);
      // Em túnel, o tema efetivo deve ser forçado para escuro (dark)
      expect(cubitWithDr.state.isEffectiveThemeDark, isTrue);

      await cubitWithDr.close();
    });

    test('deve associar activeCluster quando PoiClusterEngine for fornecido e houver alerta ativo', () async {
      final clusterEngine = const PoiClusterEngine(clusterRadiusMeters: 45.0);
      final cubitWithClusters = DashboardCubit(
        repository: mockRepo,
        alertMachine: mockAlertMachine,
        poiClusterEngine: clusterEngine,
      );

      final radar = const PoiPoint(
        id: 111,
        type: PoiType.fixedRadar,
        latitude: -23.5505,
        longitude: -46.6333,
        speedLimit: 60,
      );
      final bump = const PoiPoint(
        id: 222,
        type: PoiType.physicalSpeedBump,
        latitude: -23.5506,
        longitude: -46.6333,
      );

      when(() => mockRepo.findNearbyPois(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => [radar, bump]);

      when(() => mockAlertMachine.state).thenReturn(AlertState(
        status: AlertStatus.alerting,
        activeAlert: ActiveAlert(
          poi: radar,
          distanceMeters: 200,
          currentSpeedKmh: 50,
          status: AlertStatus.alerting,
          isOverSpeed: false,
          targetBearing: 0.0,
          relativeBearing: 0.0,
        ),
      ));

      await cubitWithClusters.onLocationUpdated(VehiclePosition(
        latitude: -23.5500,
        longitude: -46.6333,
        speedKmh: 50.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime(2026, 10, 30, 12, 0, 0),
      ));

      expect(cubitWithClusters.state.activeCluster, isNotNull);
      expect(cubitWithClusters.state.activeCluster!.isMultiPoint, isTrue);
      expect(cubitWithClusters.state.activeCluster!.primaryPoi.id, equals(111));

      await cubitWithClusters.close();
    });

    test('deve atualizar parâmetros de acessibilidade, idioma e feedback háptico', () {
      cubit.setHapticFeedback(enabled: false, intensity: HapticIntensity.strong);
      expect(cubit.state.hapticEnabled, isFalse);
      expect(cubit.state.hapticIntensity, HapticIntensity.strong);

      cubit.setLanguage(AppLanguage.es);
      expect(cubit.state.language, AppLanguage.es);

      cubit.setHighContrastMode(true);
      expect(cubit.state.highContrastMode, isTrue);
    });
  });
}
