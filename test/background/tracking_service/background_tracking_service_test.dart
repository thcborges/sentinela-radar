import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/background/tracking_service/background_tracking_service.dart';
import 'package:sentinela/core/audio/audio_alert_player.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';

class MockPoiRepository extends Mock implements PoiRepository {}
class MockAlertMachine extends Mock implements AlertMachine {}
class MockAudioAlertPlayer extends Mock implements AudioAlertPlayer {}
class MockOverlayService extends Mock implements OverlayService {}

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
  });

  setUp(() {
    mockRepository = MockPoiRepository();
    mockAlertMachine = MockAlertMachine();
    mockAudioPlayer = MockAudioAlertPlayer();
    mockOverlayService = MockOverlayService();

    when(() => mockAudioPlayer.playAlert(
          any(),
          isVoiceEnabled: any(named: 'isVoiceEnabled'),
          isBeepEnabled: any(named: 'isBeepEnabled'),
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
  });
}
