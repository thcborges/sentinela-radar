import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/background/tracking_service/background_tracking_service.dart';
import 'package:sentinela/core/audio/audio_alert_player.dart';
import 'package:sentinela/core/audio/tts_engine_interface.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';
import 'package:sqlite3/sqlite3.dart';

class MockTtsEngine extends Mock implements TtsEngineInterface {}
class MockOverlayAdapter extends Mock implements OverlayPlatformAdapter {}

void main() {
  group('Simulação de Trajeto GPX & Teste de Integração Fim a Fim (Sentinela)', () {
    late Database rawDb;
    late DatabaseManager dbManager;
    late PoiRepository poiRepository;
    late PassageRepository passageRepository;
    late AlertMachine alertMachine;
    late MockTtsEngine mockTts;
    late AudioAlertPlayer audioPlayer;
    late MockOverlayAdapter mockOverlayAdapter;
    late OverlayService overlayService;
    late BackgroundTrackingService trackingService;

    // POIs reais na simulação
    const radarPaulista = PoiPoint(
      id: 501,
      latitude: -23.550520,
      longitude: -46.633308,
      type: PoiType.fixedRadar,
      speedLimit: 60,
      direction: 180, // Sentido Sul
      roadName: 'Av. 23 de Maio',
    );

    const semaforoAugusta = PoiPoint(
      id: 502,
      latitude: -23.554000,
      longitude: -46.633308,
      type: PoiType.trafficLightRadar,
      speedLimit: 50,
      direction: 180,
      roadName: 'Cruzamento Augusta',
    );

    setUp(() async {
      rawDb = sqlite3.openInMemory();
      dbManager = DatabaseManager(rawDb);
      dbManager.initializeSchema();
      dbManager.insertPoisBatch([radarPaulista, semaforoAugusta]);

      poiRepository = PoiRepository(dbManager);
      passageRepository = PassageRepository(rawDb);
      passageRepository.initSchema();

      alertMachine = AlertMachine();

      mockTts = MockTtsEngine();
      when(() => mockTts.speak(any())).thenAnswer((_) async => true);
      audioPlayer = AudioAlertPlayer(ttsEngine: mockTts);

      mockOverlayAdapter = MockOverlayAdapter();
      when(() => mockOverlayAdapter.isPermissionGranted()).thenAnswer((_) async => true);
      when(() => mockOverlayAdapter.showOverlay(height: any(named: 'height'), width: any(named: 'width')))
          .thenAnswer((_) async => true);
      when(() => mockOverlayAdapter.shareData(any())).thenAnswer((_) async {});
      overlayService = OverlayService(adapter: mockOverlayAdapter);
      await overlayService.startOverlay();

      trackingService = BackgroundTrackingService(
        repository: poiRepository,
        alertMachine: alertMachine,
        audioPlayer: audioPlayer,
        overlayService: overlayService,
        passageRepository: passageRepository,
      );
    });

    tearDown(() async {
      await trackingService.dispose();
      rawDb.close();
    });

    test('deve executar trajeto simulado GPX: aproximação -> excesso -> passagem -> gravação de histórico', () async {
      final gpsStreamController = StreamController<VehiclePosition>();
      final receivedAlerts = <ActiveAlert?>[];

      trackingService.alertStream.listen((alert) {
        receivedAlerts.add(alert);
      });

      await trackingService.startTracking(gpsStreamController.stream);

      // Ponto 1: Veículo a ~1200m ao norte do radar (rumo sul 180°), a 70 km/h
      // Distância de alerta para 70 km/h é ~290m -> Estado deve ser idle (sem alerta ativo)
      gpsStreamController.add(VehiclePosition(
        latitude: -23.540000,
        longitude: -46.633308,
        speedKmh: 70.0,
        bearing: 180.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 8, 0, 0),
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert, isNull);
      verifyNever(() => mockTts.speak(any()));

      // Ponto 2: Veículo se aproxima a ~220m do radar a 55 km/h (dentro do limite de 60 km/h)
      // Distância <= 250m -> Dispara alerta compatível (alerting)
      gpsStreamController.add(VehiclePosition(
        latitude: -23.548540,
        longitude: -46.633308,
        speedKmh: 55.0,
        bearing: 180.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 8, 0, 15),
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert, isNotNull);
      expect(trackingService.currentAlert!.poi.id, equals(501));
      expect(trackingService.currentAlert!.isOverSpeed, isFalse);
      verify(() => mockTts.speak(any(that: contains('Radar fixo, 60 km/h')))).called(1);

      // Ponto 3: Veículo a ~80m do radar acelera para 75 km/h (> 60 km/h)
      // Dispara overSpeed
      gpsStreamController.add(VehiclePosition(
        latitude: -23.549800,
        longitude: -46.633308,
        speedKmh: 75.0,
        bearing: 180.0,
        accuracyMeters: 3.5,
        timestamp: DateTime(2026, 10, 30, 8, 0, 20),
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert, isNotNull);
      expect(trackingService.currentAlert!.isOverSpeed, isTrue);

      // Ponto 4: Veículo passa pelo radar e continua para o sul
      // Conclui a passagem pelo radar 501
      gpsStreamController.add(VehiclePosition(
        latitude: -23.551500, // Passou do radar (-23.550520)
        longitude: -46.633308,
        speedKmh: 68.0,
        bearing: 180.0,
        accuracyMeters: 3.5,
        timestamp: DateTime(2026, 10, 30, 8, 0, 25),
      ));
      await pumpEventQueue();

      // Verifica gravação no histórico de passagens
      final recentPassages = await passageRepository.getRecentPassages();
      expect(recentPassages, isNotEmpty);
      expect(recentPassages.first.poiId, equals(501));
      expect(recentPassages.first.isOverSpeed, isTrue);
      expect(recentPassages.first.roadName, equals('Av. 23 de Maio'));

      // Verifica estatísticas consolidadas
      final stats = await passageRepository.getStatsSummary();
      expect(stats.totalPassages, equals(1));
      expect(stats.overSpeedPassages, equals(1));
      expect(stats.adherenceRatePercent, equals(0.0));

      await gpsStreamController.close();
    });
  });
}
