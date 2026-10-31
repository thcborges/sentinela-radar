import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/background/tracking_service/background_tracking_service.dart';
import 'package:sentinela/core/audio/audio_alert_player.dart';
import 'package:sentinela/core/audio/tts_engine_interface.dart';
import 'package:sentinela/core/backup/backup_restore_service.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/platform/live_activity_service.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';
import 'package:sqlite3/sqlite3.dart';

class MockTtsEngine extends Mock implements TtsEngineInterface {}
class MockOverlayAdapter extends Mock implements OverlayPlatformAdapter {}

void main() {
  group('Simulação Interestadual Rodoviária & Live Activities / Tolerância Dinâmica (Sentinela)', () {
    late Database rawDb;
    late DatabaseManager dbManager;
    late PoiRepository poiRepository;
    late PassageRepository passageRepository;
    late AlertMachine alertMachine;
    late MockTtsEngine mockTts;
    late AudioAlertPlayer audioPlayer;
    late MockOverlayAdapter mockOverlayAdapter;
    late OverlayService overlayService;
    late FakeLiveActivityPlatform fakeLiveActivityPlatform;
    late LiveActivityService liveActivityService;
    late BackgroundTrackingService trackingService;
    late BackupRestoreService backupService;

    // POIs da Rodovia dos Bandeirantes (SP-348)
    const radarKm60 = PoiPoint(
      id: 601,
      latitude: -23.080000,
      longitude: -47.000000,
      type: PoiType.fixedRadar,
      speedLimit: 100,
      direction: 0, // Sentido Norte
      roadName: 'Rod. dos Bandeirantes KM 60',
    );

    const tollFreeFlowKm75 = PoiPoint(
      id: 602,
      latitude: -23.050000,
      longitude: -47.000000,
      type: PoiType.freeFlowToll,
      speedLimit: 120,
      direction: 0,
      roadName: 'Pórtico Free Flow Itupeva KM 75',
    );

    const radarMovelKm85 = PoiPoint(
      id: 603,
      latitude: -23.020000,
      longitude: -47.000000,
      type: PoiType.mobileRadar,
      speedLimit: 80,
      direction: 0,
      roadName: 'Operação Radar Móvel KM 85',
    );

    setUp(() async {
      rawDb = sqlite3.openInMemory();
      dbManager = DatabaseManager(rawDb);
      dbManager.initializeSchema();
      dbManager.insertPoisBatch([radarKm60, tollFreeFlowKm75, radarMovelKm85]);

      poiRepository = PoiRepository(dbManager);
      passageRepository = PassageRepository(rawDb);
      passageRepository.initSchema();

      // Configuração com tolerância de 7 km/h e modo silencioso
      const initialPrefs = AlertPreferences(
        speedToleranceKmh: 7.0,
        anticipationTimeSeconds: 15.0,
        alertOnlyIfOverSpeed: true,
      );

      alertMachine = AlertMachine(preferences: initialPrefs);

      mockTts = MockTtsEngine();
      when(() => mockTts.speak(any())).thenAnswer((_) async => true);
      when(() => mockTts.stop()).thenAnswer((_) async {});
      audioPlayer = AudioAlertPlayer(ttsEngine: mockTts);

      mockOverlayAdapter = MockOverlayAdapter();
      when(() => mockOverlayAdapter.isPermissionGranted()).thenAnswer((_) async => true);
      when(() => mockOverlayAdapter.showOverlay(
            height: any(named: 'height'),
            width: any(named: 'width'),
          )).thenAnswer((_) async => true);
      when(() => mockOverlayAdapter.shareData(any())).thenAnswer((_) async {});
      overlayService = OverlayService(adapter: mockOverlayAdapter);
      await overlayService.startOverlay();

      fakeLiveActivityPlatform = FakeLiveActivityPlatform(supported: true);
      liveActivityService = LiveActivityService(platform: fakeLiveActivityPlatform);

      trackingService = BackgroundTrackingService(
        repository: poiRepository,
        alertMachine: alertMachine,
        audioPlayer: audioPlayer,
        overlayService: overlayService,
        passageRepository: passageRepository,
        liveActivityService: liveActivityService,
      );

      backupService = BackupRestoreService(
        passageRepository: passageRepository,
        alertMachine: alertMachine,
      );
    });

    tearDown(() async {
      await trackingService.dispose();
      rawDb.close();
    });

    test('Cenário completo de rodovia: tolerância dinâmica, Live Activity na Dynamic Island e backup 100% offline', () async {
      final gpsController = StreamController<VehiclePosition>();
      await trackingService.startTracking(gpsController.stream);

      // Ponto 1: Veículo a 2 km ao sul do Radar KM 60, rumo Norte a 105 km/h
      // Distância ~2000m -> Fora da distância de alerta (idle)
      gpsController.add(VehiclePosition(
        latitude: -23.100000,
        longitude: -47.000000,
        speedKmh: 105.0,
        bearing: 0.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 14, 0, 0),
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert, isNull);
      expect(fakeLiveActivityPlatform.lastData?.alertStatus, equals(AlertStatus.idle));
      verifyNever(() => mockTts.speak(any()));

      // Ponto 2: Veículo se aproxima a ~330m do Radar KM 60 a 105 km/h
      // Limite = 100 km/h, Tolerância = 7 km/h -> Limite efetivo = 107 km/h.
      // 105 <= 107 -> NÃO é considerado excesso de velocidade (isOverSpeed = false).
      // Como alertOnlyIfOverSpeed = true, TTS permanece em silêncio.
      gpsController.add(VehiclePosition(
        latitude: -23.083000,
        longitude: -47.000000,
        speedKmh: 105.0,
        bearing: 0.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 14, 0, 10),
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert, isNotNull);
      expect(trackingService.currentAlert!.poi.id, equals(601));
      expect(trackingService.currentAlert!.isOverSpeed, isFalse);
      expect(fakeLiveActivityPlatform.lastData?.isAlertActive, isTrue);
      expect(fakeLiveActivityPlatform.lastData?.poiType, equals(PoiType.fixedRadar));
      expect(fakeLiveActivityPlatform.lastData?.speedLimitKmh, equals(100));
      // Modo silencioso respeitado: nenhuma emissão de áudio
      verifyNever(() => mockTts.speak(any()));

      // Ponto 3: Condutor acelera para 112 km/h (> 107 km/h limite com tolerância)
      // Dispara status overSpeed e fala de alerta
      gpsController.add(VehiclePosition(
        latitude: -23.081500,
        longitude: -47.000000,
        speedKmh: 112.0,
        bearing: 0.0,
        accuracyMeters: 3.5,
        timestamp: DateTime(2026, 10, 30, 14, 0, 15),
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert!.isOverSpeed, isTrue);
      expect(fakeLiveActivityPlatform.lastData?.alertStatus, equals(AlertStatus.overSpeed));
      verify(() => mockTts.speak(any(that: contains('Radar fixo, 100 km/h')))).called(1);

      // Ponto 4: Condutor passa pelo Radar KM 60
      gpsController.add(VehiclePosition(
        latitude: -23.078000, // Passou do radar (-23.080000)
        longitude: -47.000000,
        speedKmh: 100.0,
        bearing: 0.0,
        accuracyMeters: 3.5,
        timestamp: DateTime(2026, 10, 30, 14, 0, 20),
      ));
      await pumpEventQueue();

      // Passagem gravada localmente
      final passagesAfterRadar = await passageRepository.getRecentPassages();
      expect(passagesAfterRadar.length, equals(1));
      expect(passagesAfterRadar.first.poiId, equals(601));
      expect(passagesAfterRadar.first.isOverSpeed, isTrue);

      // Ponto 5: Veículo se aproxima do Pórtico Free Flow (KM 75) a ~400m
      gpsController.add(VehiclePosition(
        latitude: -23.053500,
        longitude: -47.000000,
        speedKmh: 115.0,
        bearing: 0.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 14, 0, 40),
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert, isNotNull);
      expect(trackingService.currentAlert!.poi.id, equals(602));
      expect(trackingService.currentAlert!.poi.type, equals(PoiType.freeFlowToll));
      expect(fakeLiveActivityPlatform.lastData?.poiType, equals(PoiType.freeFlowToll));
      expect(fakeLiveActivityPlatform.lastData?.speedLimitKmh, equals(120));

      // Ponto 6: Veículo passa pelo Pórtico Free Flow
      gpsController.add(VehiclePosition(
        latitude: -23.048000,
        longitude: -47.000000,
        speedKmh: 115.0,
        bearing: 0.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 14, 0, 45),
      ));
      await pumpEventQueue();

      final passagesAfterToll = await passageRepository.getRecentPassages();
      expect(passagesAfterToll.length, equals(2));
      expect(passagesAfterToll.first.poiId, equals(602));
      expect(passagesAfterToll.first.isOverSpeed, isFalse);

      // Ponto 7: Exportação e importação de Backup Offline
      final backupJson = await backupService.exportBackupToJson();
      expect(backupJson, contains('"version": 1'));
      expect(backupJson, contains('"speedToleranceKmh": 7'));
      expect(backupJson, contains('Rod. dos Bandeirantes KM 60'));
      expect(backupJson, contains('Pórtico Free Flow Itupeva KM 75'));

      // Restauração em banco vazio
      final restoredRawDb = sqlite3.openInMemory();
      final restoredPassageRepo = PassageRepository(restoredRawDb);
      restoredPassageRepo.initSchema();
      final freshAlertMachine = AlertMachine();
      final restoreManager = BackupRestoreService(
        passageRepository: restoredPassageRepo,
        alertMachine: freshAlertMachine,
      );

      final summary = await restoreManager.importBackupFromJson(backupJson);
      expect(summary.isSuccess, isTrue);
      expect(summary.restoredPassagesCount, equals(2));
      expect(summary.preferencesRestored, isTrue);
      expect(summary.restoredPreferences?.speedToleranceKmh, equals(7.0));
      expect(summary.restoredPreferences?.alertOnlyIfOverSpeed, isTrue);
      expect(freshAlertMachine.preferences.speedToleranceKmh, equals(7.0));

      final restoredPassages = await restoredPassageRepo.getRecentPassages();
      expect(restoredPassages.length, equals(2));

      restoredRawDb.close();
      await gpsController.close();
    });
  });
}
