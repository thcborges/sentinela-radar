import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/audio/tts_alert_formatter.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/l10n/app_language.dart';
import 'package:sentinela/core/l10n/app_localizations.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/platform/haptic_feedback_engine.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/custom_poi_repository.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sqlite3/sqlite3.dart';

class TestHapticBridge implements HapticPlatformBridge {
  final List<String> calls = [];

  @override
  Future<void> selectionClick() async => calls.add('selectionClick');

  @override
  Future<void> lightImpact() async => calls.add('lightImpact');

  @override
  Future<void> mediumImpact() async => calls.add('mediumImpact');

  @override
  Future<void> heavyImpact() async => calls.add('heavyImpact');

  @override
  Future<void> vibrate() async => calls.add('vibrate');

  void clear() => calls.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseManager dbManager;
  late PoiRepository poiRepo;
  late CustomPoiRepository customRepo;
  late TestHapticBridge hapticBridge;
  late HapticFeedbackEngine hapticEngine;
  late AlertMachine alertMachine;
  late DashboardCubit dashboardCubit;

  setUp(() {
    db = sqlite3.openInMemory();
    dbManager = DatabaseManager(db)..initializeSchema();

    // Insere radar de teste na Rodovia dos Imigrantes (km 28, rumo Sul 180°, 80 km/h)
    dbManager.insertPoisBatch([
      const PoiPoint(
        id: 7001,
        latitude: -23.7500,
        longitude: -46.6000,
        type: PoiType.fixedRadar,
        speedLimit: 80,
        direction: 180,
        roadName: 'SP-160 Rod. dos Imigrantes',
      ),
    ]);

    customRepo = CustomPoiRepository(db);
    poiRepo = PoiRepository(dbManager, customPoiRepository: customRepo);
    hapticBridge = TestHapticBridge();
    hapticEngine = HapticFeedbackEngine(bridge: hapticBridge);

    alertMachine = AlertMachine(
      preferences: const AlertPreferences(
        soundEnabled: false, // Condutor com deficiência auditiva ou som mutado
        voiceEnabled: false,
        hapticEnabled: true,
        hapticIntensity: HapticIntensity.strong,
      ),
    );

    dashboardCubit = DashboardCubit(
      repository: poiRepo,
      alertMachine: alertMachine,
      customPoiRepository: customRepo,
      hapticEngine: hapticEngine,
    );
  });

  tearDown(() async {
    await dashboardCubit.close();
    db.close();
  });

  group('Simulação de Integração Hermética: Acessibilidade Universal & Feedback Háptico', () {
    test('Travessia completa com alertas táteis em velocidade compatível, sobrevelocidade e troca de idioma', () async {
      // 1. Veículo se aproxima do radar a ~240m de distância rumo Sul (180°) a 75 km/h (compatível com 80 km/h)
      await dashboardCubit.onLocationUpdated(
        VehiclePosition(
          latitude: -23.7478,
          longitude: -46.6000,
          speedKmh: 75.0,
          bearing: 180.0,
          accuracyMeters: 4.0,
          timestamp: DateTime(2026, 10, 30, 14, 0, 0),
        ),
      );

      expect(dashboardCubit.state.alertStatus, equals(AlertStatus.alerting));
      expect(dashboardCubit.state.activeAlert, isNotNull);
      expect(dashboardCubit.state.activeAlert!.isOverSpeed, isFalse);

      // Deve ter disparado pulso tátil de aproximação de radar
      expect(hapticBridge.calls, contains('heavyImpact'));

      // 2. Condutor acelera inadvertidamente para 98 km/h em direção ao radar
      hapticBridge.clear();
      hapticEngine.resetDebounce();

      await dashboardCubit.onLocationUpdated(
        VehiclePosition(
          latitude: -23.7488,
          longitude: -46.6000,
          speedKmh: 98.0,
          bearing: 180.0,
          accuracyMeters: 4.0,
          timestamp: DateTime(2026, 10, 30, 14, 0, 5),
        ),
      );

      expect(dashboardCubit.state.alertStatus, equals(AlertStatus.overSpeed));
      expect(dashboardCubit.state.activeAlert!.isOverSpeed, isTrue);

      // Deve ter acionado a vibração crítica de advertência
      expect(hapticBridge.calls, contains('vibrate'));

      // 3. Condutor percebe a vibração, freia para 72 km/h e cruza o radar com segurança
      hapticBridge.clear();

      await dashboardCubit.onLocationUpdated(
        VehiclePosition(
          latitude: -23.7510, // ultrapassou o ponto -23.7500
          longitude: -46.6000,
          speedKmh: 72.0,
          bearing: 180.0,
          accuracyMeters: 4.0,
          timestamp: DateTime(2026, 10, 30, 14, 0, 10),
        ),
      );

      expect(dashboardCubit.state.alertStatus, equals(AlertStatus.passed));

      // Deve ter acionado a confirmação suave de ultrapassagem
      expect(hapticBridge.calls, contains('mediumImpact'));

      // 4. Teste de Internacionalização Dinâmica (i18n): Alterna idioma para Inglês
      dashboardCubit.setLanguage(AppLanguage.en);
      expect(dashboardCubit.state.language, equals(AppLanguage.en));

      final locEn = AppLocalizations(dashboardCubit.state.language);
      expect(locEn.poiTypeName(PoiType.fixedRadar), equals('Fixed Speed Camera'));

      const poiEn = PoiPoint(
        id: 7001,
        latitude: -23.7500,
        longitude: -46.6000,
        type: PoiType.fixedRadar,
        speedLimit: 80,
      );
      final spokenAlertEn = TtsAlertFormatter.formatPoiAlert(poiEn, language: dashboardCubit.state.language);
      expect(spokenAlertEn, equals('Fixed speed camera, 80 km/h ahead'));

      // 5. Condutor avista e reporta rapidamente um ponto perigoso na via
      hapticBridge.clear();
      final reported = await dashboardCubit.reportQuickPoi(
        type: PoiType.mobileRadar,
        speedLimit: 80,
        description: 'Viatura policial com radar portátil',
      );

      expect(reported, isNotNull);
      expect(hapticBridge.calls, contains('mediumImpact'));
      expect(dashboardCubit.state.userPoiCount, equals(1));
    });
  });
}
