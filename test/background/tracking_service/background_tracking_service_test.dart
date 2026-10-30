import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/background/tracking_service/background_tracking_service.dart';
import 'package:sentinela/core/audio/audio_alert_player.dart';
import 'package:sentinela/core/engine/adaptive_gps_sampler.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/platform/live_activity_service.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}
class MockAudioAlertPlayer extends Mock implements AudioAlertPlayer {}
class MockOverlayService extends Mock implements OverlayService {}
class MockPassageRepository extends Mock implements PassageRepository {}

void main() {
  late MockPoiRepository mockRepository;
  late MockAlertMachine mockAlertMachine;
  late MockAudioAlertPlayer mockAudioPlayer;
  late MockOverlayService mockOverlayService;
  late BackgroundTrackingService trackingService;

  setUpAll(() {
    registerFallbackValue(VehiclePosition(
      latitude: 0,
      longitude: 0,
      speedKmh: 0,
      bearing: 0,
      accuracyMeters: 5.0,
      timestamp: DateTime(2026, 1, 1),
    ));
    const dummyPoi = PoiPoint(
      id: 0,
      latitude: 0,
      longitude: 0,
      type: PoiType.fixedRadar,
    );
    registerFallbackValue(const ActiveAlert(
      poi: dummyPoi,
      distanceMeters: 100,
      currentSpeedKmh: 50,
      status: AlertStatus.alerting,
      isOverSpeed: false,
      targetBearing: 0,
      relativeBearing: 0,
    ));
    registerFallbackValue(PassageRecord(
      poiId: 0,
      poiType: PoiType.fixedRadar,
      vehicleSpeedKmh: 0,
      timestamp: DateTime(2026, 1, 1),
      isOverSpeed: false,
    ));
  });

  setUp(() {
    mockRepository = MockPoiRepository();
    mockAlertMachine = MockAlertMachine();
    mockAudioPlayer = MockAudioAlertPlayer();
    mockOverlayService = MockOverlayService();

    when(() => mockAlertMachine.preferences).thenReturn(const AlertPreferences());

    when(() => mockAudioPlayer.playAlert(
          any(),
          isVoiceEnabled: any(named: 'isVoiceEnabled'),
          isBeepEnabled: any(named: 'isBeepEnabled'),
          alertOnlyIfOverSpeed: any(named: 'alertOnlyIfOverSpeed'),
        )).thenAnswer((_) async {});

    when(() => mockOverlayService.updateOverlayData(
          speedKmh: any(named: 'speedKmh'),
          alert: any(named: 'alert'),
        )).thenAnswer((_) async {});

    trackingService = BackgroundTrackingService(
      repository: mockRepository,
      alertMachine: mockAlertMachine,
      audioPlayer: mockAudioPlayer,
      overlayService: mockOverlayService,
    );
  });

  tearDown(() async {
    await trackingService.stopTracking();
  });

  group('BackgroundTrackingService (Foreground Service & Rastreamento em Segundo Plano)', () {
    test('deve inicializar com estado parado (isRunning = false)', () {
      expect(trackingService.isRunning, isFalse);
      expect(trackingService.currentAlert, isNull);
      expect(trackingService.lastPosition, isNull);
    });

    test('deve processar coordenadas de GPS, consultar POIs e despachar alertas de áudio e overlay', () async {
      final gpsController = StreamController<VehiclePosition>();

      final position = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 65.0,
        bearing: 90.0,
        accuracyMeters: 5.0,
        timestamp: DateTime(2026, 1, 1),
      );

      const poi = PoiPoint(
        id: 42,
        latitude: -23.5500,
        longitude: -46.6300,
        type: PoiType.fixedRadar,
        speedLimit: 60,
      );

      const activeAlert = ActiveAlert(
        poi: poi,
        distanceMeters: 250,
        currentSpeedKmh: 65,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 90,
        relativeBearing: 0,
      );

      when(() => mockRepository.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => [poi]);

      when(() => mockAlertMachine.updatePosition(any(), any()))
          .thenReturn(null);

      when(() => mockAlertMachine.state).thenReturn(
        const AlertState(
          status: AlertStatus.overSpeed,
          activeAlert: activeAlert,
          nearbyAlerts: [activeAlert],
        ),
      );

      await trackingService.startTracking(gpsController.stream);
      expect(trackingService.isRunning, isTrue);

      gpsController.add(position);
      await pumpEventQueue();

      expect(trackingService.lastPosition, equals(position));
      expect(trackingService.currentAlert, equals(activeAlert));

      verify(() => mockRepository.findNearbyPois(
            latitude: -23.5505,
            longitude: -46.6333,
            radiusMeters: 1200.0,
          )).called(1);

      verify(() => mockAudioPlayer.playAlert(
            activeAlert,
            isVoiceEnabled: true,
            isBeepEnabled: true,
          )).called(1);

      verify(() => mockOverlayService.updateOverlayData(
            speedKmh: 65.0,
            alert: activeAlert,
          )).called(1);

      await gpsController.close();
    });

    test('não deve consultar banco quando coordenada de GPS for imprecisa', () async {
      final gpsController = StreamController<VehiclePosition>();

      final inaccuratePosition = VehiclePosition(
        latitude: 0,
        longitude: 0,
        speedKmh: 0,
        bearing: 0,
        accuracyMeters: 50.0, // > 35m -> isAccurate = false
        timestamp: DateTime(2026, 1, 1),
      );

      await trackingService.startTracking(gpsController.stream);
      gpsController.add(inaccuratePosition);
      await pumpEventQueue();

      verifyNever(() => mockRepository.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          ));

      await gpsController.close();
    });

    test('deve cancelar subscrição e limpar referências ao parar tracking', () async {
      final gpsController = StreamController<VehiclePosition>();

      await trackingService.startTracking(gpsController.stream);
      expect(trackingService.isRunning, isTrue);

      await trackingService.stopTracking();
      expect(trackingService.isRunning, isFalse);
      expect(trackingService.currentAlert, isNull);

      await gpsController.close();
    });

    test('deve emitir eventos em alertStream e positionStream e suportar dispose', () async {
      final gpsController = StreamController<VehiclePosition>();

      final position = VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 50.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: DateTime(2026, 1, 1),
      );

      when(() => mockRepository.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => []);

      when(() => mockAlertMachine.updatePosition(any(), any()))
          .thenReturn(null);

      when(() => mockAlertMachine.state).thenReturn(
        const AlertState(status: AlertStatus.idle),
      );

      final positions = <VehiclePosition>[];
      final alerts = <ActiveAlert?>[];

      final sub1 = trackingService.positionStream.listen(positions.add);
      final sub2 = trackingService.alertStream.listen(alerts.add);

      await trackingService.startTracking(gpsController.stream);
      gpsController.add(position);
      // Emitir erro para testar onError
      gpsController.addError('GPS timeout');
      await pumpEventQueue();

      expect(positions, contains(position));
      expect(alerts, contains(isNull));

      await sub1.cancel();
      await sub2.cancel();
      await trackingService.dispose();
      expect(trackingService.isRunning, isFalse);

      await gpsController.close();
    });

    test('deve gravar passagem no PassageRepository ao concluir alerta', () async {
      final mockPassageRepo = MockPassageRepository();
      when(() => mockPassageRepo.insertPassage(any())).thenAnswer((_) async => 1);

      final serviceWithPassages = BackgroundTrackingService(
        repository: mockRepository,
        alertMachine: mockAlertMachine,
        audioPlayer: mockAudioPlayer,
        overlayService: mockOverlayService,
        passageRepository: mockPassageRepo,
      );

      final gpsController = StreamController<VehiclePosition>();

      const poi = PoiPoint(
        id: 77,
        latitude: -23.5,
        longitude: -46.6,
        type: PoiType.fixedRadar,
        speedLimit: 60,
        roadName: 'Av. Paulista',
      );

      const alert = ActiveAlert(
        poi: poi,
        distanceMeters: 50,
        currentSpeedKmh: 65,
        status: AlertStatus.overSpeed,
        isOverSpeed: true,
        targetBearing: 0,
        relativeBearing: 0,
      );

      when(() => mockRepository.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => [poi]);

      when(() => mockAlertMachine.updatePosition(any(), any())).thenReturn(null);

      // 1ª Coordenada: Alerta ativo
      when(() => mockAlertMachine.state).thenReturn(
        const AlertState(status: AlertStatus.overSpeed, activeAlert: alert),
      );

      await serviceWithPassages.startTracking(gpsController.stream);

      final pos1 = VehiclePosition(
        latitude: -23.5,
        longitude: -46.6,
        speedKmh: 65,
        bearing: 0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 30, 10, 0),
      );
      gpsController.add(pos1);
      await pumpEventQueue();

      expect(serviceWithPassages.currentAlert, equals(alert));

      // 2ª Coordenada: Passagem concluída (passed)
      when(() => mockAlertMachine.state).thenReturn(
        const AlertState(status: AlertStatus.passed, activeAlert: null),
      );

      final pos2 = VehiclePosition(
        latitude: -23.501,
        longitude: -46.6,
        speedKmh: 62,
        bearing: 0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 30, 10, 0, 5),
      );
      gpsController.add(pos2);
      await pumpEventQueue();

      verify(() => mockPassageRepo.insertPassage(any(that: isA<PassageRecord>()
          .having((p) => p.poiId, 'poiId', 77)
          .having((p) => p.isOverSpeed, 'isOverSpeed', true)
          .having((p) => p.roadName, 'roadName', 'Av. Paulista')))).called(1);

      await serviceWithPassages.dispose();
      await gpsController.close();
    });

    test('deve registrar tollFee ao passar por portal Free Flow ou praça de pedágio', () async {
      final mockPassageRepo = MockPassageRepository();
      when(() => mockPassageRepo.insertPassage(any())).thenAnswer((_) async => 1);

      final service = BackgroundTrackingService(
        repository: mockRepository,
        alertMachine: mockAlertMachine,
        audioPlayer: mockAudioPlayer,
        overlayService: mockOverlayService,
        passageRepository: mockPassageRepo,
      );

      final gpsController = StreamController<VehiclePosition>();

      const freeFlowPoi = PoiPoint(
        id: 999,
        latitude: -23.1,
        longitude: -46.2,
        type: PoiType.freeFlowToll,
        roadName: 'SP-099 Free Flow',
      );

      const alert = ActiveAlert(
        poi: freeFlowPoi,
        distanceMeters: 50,
        currentSpeedKmh: 90,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      when(() => mockRepository.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => [freeFlowPoi]);

      when(() => mockAlertMachine.updatePosition(any(), any())).thenReturn(null);

      // Alerta ativo
      when(() => mockAlertMachine.state).thenReturn(
        const AlertState(status: AlertStatus.alerting, activeAlert: alert),
      );

      await service.startTracking(gpsController.stream);

      gpsController.add(VehiclePosition(
        latitude: -23.1,
        longitude: -46.2,
        speedKmh: 90,
        bearing: 0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 30, 10, 0),
      ));
      await pumpEventQueue();

      // Passou do ponto
      when(() => mockAlertMachine.state).thenReturn(
        const AlertState(status: AlertStatus.passed, activeAlert: null),
      );

      gpsController.add(VehiclePosition(
        latitude: -23.101,
        longitude: -46.2,
        speedKmh: 90,
        bearing: 0,
        accuracyMeters: 5,
        timestamp: DateTime(2026, 10, 30, 10, 0, 5),
      ));
      await pumpEventQueue();

      verify(() => mockPassageRepo.insertPassage(any(that: isA<PassageRecord>()
          .having((p) => p.poiId, 'poiId', 999)
          .having((p) => p.poiType, 'poiType', PoiType.freeFlowToll)
          .having((p) => p.tollFee, 'tollFee', 4.20)))).called(1);

      await service.dispose();
      await gpsController.close();
    });

    test('deve atualizar AdaptiveGpsSampler e redefinir ao parar tracking', () async {
      when(() => mockAlertMachine.state).thenReturn(const AlertState(status: AlertStatus.idle));
      final sampler = AdaptiveGpsSampler(stationaryThreshold: const Duration(seconds: 10));
      when(() => mockRepository.findNearbyPois(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            radiusMeters: any(named: 'radiusMeters'),
          )).thenAnswer((_) async => []);

      final serviceWithSampler = BackgroundTrackingService(
        repository: mockRepository,
        alertMachine: mockAlertMachine,
        audioPlayer: mockAudioPlayer,
        overlayService: mockOverlayService,
        adaptiveSampler: sampler,
      );

      final gpsController = StreamController<VehiclePosition>();
      await serviceWithSampler.startTracking(gpsController.stream);

      final t0 = DateTime(2026, 10, 30, 10, 0, 0);
      gpsController.add(VehiclePosition(
        latitude: -23.5,
        longitude: -46.6,
        speedKmh: 0.0,
        bearing: 0,
        accuracyMeters: 5,
        timestamp: t0,
      ));
      await pumpEventQueue();
      expect(sampler.isStationary, isFalse);

      gpsController.add(VehiclePosition(
        latitude: -23.5,
        longitude: -46.6,
        speedKmh: 0.0,
        bearing: 0,
        accuracyMeters: 5,
        timestamp: t0.add(const Duration(seconds: 15)),
      ));
      await pumpEventQueue();
      expect(sampler.isStationary, isTrue);

      await serviceWithSampler.stopTracking();
      expect(sampler.isStationary, isFalse);

      await serviceWithSampler.dispose();
      await gpsController.close();
    });

    test('deve atualizar LiveActivityService quando fornecido e parar ao encerrar', () async {
      final fakePlatform = FakeLiveActivityPlatform(supported: true);
      final liveService = LiveActivityService(platform: fakePlatform);

      final serviceWithLive = BackgroundTrackingService(
        repository: mockRepository,
        alertMachine: mockAlertMachine,
        audioPlayer: mockAudioPlayer,
        overlayService: mockOverlayService,
        liveActivityService: liveService,
      );

      final gpsController = StreamController<VehiclePosition>();
      await serviceWithLive.startTracking(gpsController.stream);

      const candidatePoi = PoiPoint(
        id: 77,
        latitude: -23.5505,
        longitude: -46.6330,
        type: PoiType.fixedRadar,
        speedLimit: 60,
        roadName: 'Av. 23 de Maio',
      );

      when(() => mockRepository.findNearbyPois(
        latitude: -23.5505,
        longitude: -46.6333,
        radiusMeters: any(named: 'radiusMeters'),
      )).thenAnswer((_) async => [candidatePoi]);

      const activeAlert = ActiveAlert(
        poi: candidatePoi,
        distanceMeters: 200,
        currentSpeedKmh: 65,
        status: AlertStatus.alerting,
        isOverSpeed: false,
        targetBearing: 0,
        relativeBearing: 0,
      );

      when(() => mockAlertMachine.updatePosition(any(), any())).thenReturn(null);
      when(() => mockAlertMachine.state).thenReturn(const AlertState(
        status: AlertStatus.alerting,
        activeAlert: activeAlert,
      ));

      gpsController.add(VehiclePosition(
        latitude: -23.5505,
        longitude: -46.6333,
        speedKmh: 65,
        bearing: 0,
        accuracyMeters: 5.0,
        timestamp: DateTime(2026, 10, 30, 10, 0),
      ));
      await pumpEventQueue();

      expect(liveService.isActive, isTrue);
      expect(liveService.currentData?.currentSpeedKmh, equals(65.0));
      expect(liveService.currentData?.speedLimitKmh, equals(60));
      expect(liveService.currentData?.roadName, equals('Av. 23 de Maio'));

      await serviceWithLive.stopTracking();
      expect(liveService.isActive, isFalse);

      await serviceWithLive.dispose();
      await gpsController.close();
    });
  });
}
