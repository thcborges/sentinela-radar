import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/background/tracking_service/background_tracking_service.dart';
import 'package:sentinela/core/audio/audio_alert_player.dart';
import 'package:sentinela/core/audio/tone_generator.dart';
import 'package:sentinela/core/audio/tts_engine_interface.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/toll/toll_rate_estimator.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';
import 'package:sqlite3/sqlite3.dart';

class MockTtsEngine extends Mock implements TtsEngineInterface {}
class MockOverlayPlatformAdapter extends Mock implements OverlayPlatformAdapter {}

void main() {
  group('Simulação Noturna de Condução: HUD Espelho, Bipes Sonar e Tarifação Free Flow', () {
    late Database rawDb;
    late DatabaseManager dbManager;
    late PoiRepository poiRepository;
    late PassageRepository passageRepository;
    late AlertMachine alertMachine;
    late MockTtsEngine mockTts;
    late FakeToneGenerator fakeToneGenerator;
    late AudioAlertPlayer audioPlayer;
    late MockOverlayPlatformAdapter mockOverlayAdapter;
    late OverlayService overlayService;
    late BackgroundTrackingService trackingService;
    late DashboardCubit dashboardCubit;
    const tollEstimator = TollRateEstimator();

    // POIs ao longo da Rodovia SP-099 (Sentido Norte, bearing 0°)
    const freeFlowPortico = PoiPoint(
      id: 101,
      latitude: -23.3000,
      longitude: -45.9000,
      type: PoiType.freeFlowToll,
      speedLimit: 90,
      direction: 0,
      roadName: 'SP-099 Free Flow KM 14',
    );

    const radarFixo = PoiPoint(
      id: 102,
      latitude: -23.2500,
      longitude: -45.9000,
      type: PoiType.fixedRadar,
      speedLimit: 80,
      direction: 0,
      roadName: 'SP-099 Radar Fixo KM 18',
    );

    const pracaPedagio = PoiPoint(
      id: 103,
      latitude: -23.2000,
      longitude: -45.9000,
      type: PoiType.tollBooth,
      speedLimit: 40,
      direction: 0,
      roadName: 'SP-099 Praça Pedágio KM 25',
    );

    setUp(() {
      rawDb = sqlite3.openInMemory();
      dbManager = DatabaseManager(rawDb);
      dbManager.initializeSchema();
      dbManager.insertPoisBatch([freeFlowPortico, radarFixo, pracaPedagio]);

      poiRepository = PoiRepository(dbManager);
      passageRepository = PassageRepository(rawDb);
      passageRepository.initSchema();

      const preferences = AlertPreferences(
        anticipationTimeSeconds: 15.0,
      );
      alertMachine = AlertMachine(preferences: preferences);

      mockTts = MockTtsEngine();
      when(() => mockTts.speak(any())).thenAnswer((_) async => true);
      fakeToneGenerator = FakeToneGenerator();

      audioPlayer = AudioAlertPlayer(
        ttsEngine: mockTts,
        toneGenerator: fakeToneGenerator,
      );

      mockOverlayAdapter = MockOverlayPlatformAdapter();
      when(() => mockOverlayAdapter.isPermissionGranted()).thenAnswer((_) async => true);
      when(() => mockOverlayAdapter.showOverlay(
            height: any(named: 'height'),
            width: any(named: 'width'),
          )).thenAnswer((_) async => true);
      when(() => mockOverlayAdapter.shareData(any())).thenAnswer((_) async {});
      overlayService = OverlayService(adapter: mockOverlayAdapter);

      trackingService = BackgroundTrackingService(
        repository: poiRepository,
        alertMachine: alertMachine,
        audioPlayer: audioPlayer,
        overlayService: overlayService,
        passageRepository: passageRepository,
        tollEstimator: tollEstimator,
        isVoiceEnabled: true,
        isBeepEnabled: true,
      );

      dashboardCubit = DashboardCubit(
        repository: poiRepository,
        alertMachine: alertMachine,
      );
    });

    tearDown(() async {
      await trackingService.dispose();
      await dashboardCubit.close();
      rawDb.close();
    });

    test('deve projetar HUD espelho noturno, sintetizar bipes de proximidade e registrar custos de pedágio', () async {
      // 1. Condutor ativa o Modo Espelho HUD para colocar o celular no painel sob o para-brisa
      expect(dashboardCubit.state.isHudMirrorMode, isFalse);
      dashboardCubit.toggleHudMirrorMode();
      expect(dashboardCubit.state.isHudMirrorMode, isTrue);

      final gpsStreamController = StreamController<VehiclePosition>();
      await trackingService.startTracking(gpsStreamController.stream);

      // ETAPA A: Aproximação e passagem pelo pórtico Free Flow (KM 14)
      // Carro a 88 km/h (limite 90 km/h) a 300m do pórtico
      final t0 = DateTime(2026, 10, 30, 21, 0, 0);
      gpsStreamController.add(VehiclePosition(
        latitude: -23.3030,
        longitude: -45.9000,
        speedKmh: 88.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert, isNotNull);
      expect(trackingService.currentAlert?.poi.type, equals(PoiType.freeFlowToll));
      expect(fakeToneGenerator.playedTones, isNotEmpty);
      expect(fakeToneGenerator.playedTones.last['frequencyHz'], equals(880.0)); // Tom normal 880 Hz

      // Conclui passagem pelo pórtico Free Flow
      gpsStreamController.add(VehiclePosition(
        latitude: -23.2980,
        longitude: -45.9000,
        speedKmh: 88.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t0.add(const Duration(seconds: 4)),
      ));
      await pumpEventQueue();

      // ETAPA B: Aproximação do Radar Fixo (KM 18) com Excesso de Velocidade
      // Limite 80 km/h, condutor a 105 km/h
      audioPlayer.reset();
      fakeToneGenerator.playedTones.clear();

      final t1 = t0.add(const Duration(seconds: 30));
      gpsStreamController.add(VehiclePosition(
        latitude: -23.2530,
        longitude: -45.9000,
        speedKmh: 105.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t1,
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert, isNotNull);
      expect(trackingService.currentAlert?.isOverSpeed, isTrue);
      expect(fakeToneGenerator.playedTones, isNotEmpty);
      // Tom agudo urgente de excesso de velocidade: 1200 Hz
      expect(fakeToneGenerator.playedTones.last['frequencyHz'], equals(1200.0));
      expect(fakeToneGenerator.playedTones.last['durationMs'], equals(120));

      // Passou do radar fixo
      gpsStreamController.add(VehiclePosition(
        latitude: -23.2480,
        longitude: -45.9000,
        speedKmh: 78.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t1.add(const Duration(seconds: 5)),
      ));
      await pumpEventQueue();

      // ETAPA C: Passagem por Praça de Pedágio Convencional (KM 25) a 38 km/h (limite 40)
      audioPlayer.reset();
      fakeToneGenerator.playedTones.clear();

      final t2 = t1.add(const Duration(seconds: 60));
      gpsStreamController.add(VehiclePosition(
        latitude: -23.2030,
        longitude: -45.9000,
        speedKmh: 38.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t2,
      ));
      await pumpEventQueue();

      expect(trackingService.currentAlert?.poi.type, equals(PoiType.tollBooth));
      expect(fakeToneGenerator.playedTones.last['frequencyHz'], equals(880.0));

      // Passou da praça de pedágio
      gpsStreamController.add(VehiclePosition(
        latitude: -23.1970,
        longitude: -45.9000,
        speedKmh: 45.0,
        bearing: 0.0,
        accuracyMeters: 5.0,
        timestamp: t2.add(const Duration(seconds: 6)),
      ));
      await pumpEventQueue();

      // Encerra GPS
      await gpsStreamController.close();

      // VALIDAÇÕES FINAIS DE PERSISTÊNCIA E CUSTOS DE VIAGEM
      final recentPassages = await passageRepository.getRecentPassages(limit: 10);
      expect(recentPassages.length, equals(3));

      // Resumo estatístico
      final stats = await passageRepository.getStatsSummary();
      expect(stats.totalPassages, equals(3));
      expect(stats.overSpeedPassages, equals(1));
      // Custo acumulado total: R$ 4,20 (Free Flow) + R$ 8,50 (Pedágio Convencional) = R$ 12,70
      expect(stats.totalTollCost, closeTo(12.70, 0.01));

      // Cálculo de viagem pelo TollRateEstimator
      final tripSummary = tollEstimator.calculateTripSummary(recentPassages);
      expect(tripSummary.freeFlowCount, equals(1));
      expect(tripSummary.tollBoothCount, equals(1));
      expect(tripSummary.totalTollPoints, equals(2));
      expect(tripSummary.totalCost, closeTo(12.70, 0.01));
      expect(tripSummary.formatCurrency(), equals('R\$ 12,70'));

      // Estado do HUD preservado
      expect(dashboardCubit.state.isHudMirrorMode, isTrue);
    });
  });
}