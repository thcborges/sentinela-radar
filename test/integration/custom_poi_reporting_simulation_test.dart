import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/export/route_exporter.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/repository/custom_poi_repository.dart';
import 'package:sentinela/data/repository/poi_repository.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('Simulação de Marcação Offline de POIs, Alerta e Swap Atômico (Sentinela)', () {
    late Database db;
    late DatabaseManager dbManager;
    late CustomPoiRepository customPoiRepo;
    late PoiRepository poiRepo;
    late PassageRepository passageRepo;
    late AlertMachine alertMachine;
    late DashboardCubit dashboardCubit;
    late PoiSyncService syncService;

    setUp(() {
      db = sqlite3.openInMemory();
      dbManager = DatabaseManager(db);
      dbManager.initializeSchema();

      customPoiRepo = CustomPoiRepository(db);
      customPoiRepo.initializeSchema();

      poiRepo = PoiRepository(dbManager, customPoiRepository: customPoiRepo);
      passageRepo = PassageRepository(db);
      passageRepo.initSchema();

      alertMachine = AlertMachine();
      syncService = PoiSyncService(db);

      dashboardCubit = DashboardCubit(
        repository: poiRepo,
        alertMachine: alertMachine,
        customPoiRepository: customPoiRepo,
      );
    });

    tearDown(() {
      dashboardCubit.close();
      syncService.dispose();
      db.close();
    });

    test('Cenário Completo: Marcação de Radar Móvel -> Alerta Sonar/HUD -> Blindagem no Swap Atômico -> Exportação', () async {
      // 1. Veículo trafegando na Rodovia BR-116 km 210 a 90 km/h
      final pos1 = VehiclePosition(
        latitude: -23.4600,
        longitude: -46.5300,
        speedKmh: 90.0,
        bearing: 45.0,
        accuracyMeters: 4.0,
        timestamp: DateTime(2026, 10, 30, 14, 0, 0),
      );
      await dashboardCubit.onLocationUpdated(pos1);

      expect(dashboardCubit.state.alertStatus, AlertStatus.idle);
      expect(dashboardCubit.state.userPoiCount, 0);

      // 2. Condutor avista viatura com radar portátil móvel e toca em "Marcar Ponto"
      final reported = await dashboardCubit.reportQuickPoi(
        type: PoiType.mobileRadar,
        speedLimit: 80,
        roadName: 'BR-116 km 210',
        description: 'Viatura PRF com radar estático',
      );

      expect(reported, isNotNull);
      expect(reported!.type, PoiType.mobileRadar);
      expect(dashboardCubit.state.userPoiCount, 1);

      // 3. Na aproximação seguinte a 250m do ponto registrado, o motor de alerta detecta excesso de velocidade (90 km/h num limite de 80)
      final posApproaching = VehiclePosition(
        latitude: -23.4618,
        longitude: -46.5318,
        speedKmh: 92.0,
        bearing: 45.0,
        accuracyMeters: 3.5,
        timestamp: DateTime(2026, 10, 30, 14, 0, 10),
      );
      await dashboardCubit.onLocationUpdated(posApproaching);

      expect(dashboardCubit.state.activeAlert, isNotNull);
      expect(dashboardCubit.state.activeAlert!.poi.type, PoiType.mobileRadar);
      expect(dashboardCubit.state.activeAlert!.poi.source, 'user_reported');
      expect(dashboardCubit.state.alertStatus, AlertStatus.overSpeed);
      expect(dashboardCubit.state.nearbySonarPois.isNotEmpty, isTrue);

      // 4. Veículo passa pelo radar e registra no histórico de passagens
      await passageRepo.insertPassage(PassageRecord(
        poiId: dashboardCubit.state.activeAlert!.poi.id,
        poiType: dashboardCubit.state.activeAlert!.poi.type,
        vehicleSpeedKmh: 92.0,
        speedLimit: 80,
        isOverSpeed: true,
        timestamp: DateTime(2026, 10, 30, 14, 0, 20),
        roadName: 'BR-116 km 210',
        latitude: posApproaching.latitude,
        longitude: posApproaching.longitude,
      ));

      final passages = await passageRepo.getRecentPassages();
      expect(passages.length, 1);
      expect(passages.first.isOverSpeed, isTrue);

      // 5. O usuário conecta ao Wi-Fi e sincroniza dados federais (DNIT / ANTT) via swap atômico
      const dnitUpdateCsv = '''id,uf,rodovia,km,municipio,tipo_equipamento,velocidade_regulamentada,latitude,longitude,sentido
701,SP,BR-116,215.0,Arujá,Radar Fixo,100,-23.4000,-46.4500,Ambos
''';
      final syncSuccess = await syncService.syncFromFederalData(
        dnitPayload: dnitUpdateCsv,
        isCsv: true,
      );
      expect(syncSuccess, isTrue);

      // A base pública tem agora 1 ponto oficial...
      expect(dbManager.getTotalCount(), 1);

      // MAS o ponto customizado do usuário continua 100% preservado e ativo!
      final customCount = await customPoiRepo.getCustomPoiCount();
      expect(customCount, 1);

      final userPois = await customPoiRepo.getAllCustomPois();
      expect(userPois.first.description, 'Viatura PRF com radar estático');

      // 6. Exportação do trajeto com o waypoint do radar móvel registrado
      final trackPoints = [
        TrackPoint(latitude: pos1.latitude, longitude: pos1.longitude, speedKmh: pos1.speedKmh, timestamp: pos1.timestamp),
        TrackPoint(latitude: posApproaching.latitude, longitude: posApproaching.longitude, speedKmh: posApproaching.speedKmh, timestamp: posApproaching.timestamp),
      ];

      final waypoints = [
        PassageWaypoint(
          name: 'Radar Móvel Marcado (80 km/h)',
          latitude: posApproaching.latitude,
          longitude: posApproaching.longitude,
          speedKmh: 92.0,
          speedLimit: 80,
          isOverSpeed: true,
          description: 'BR-116 km 210 - Velocidade: 92.0 km/h',
          timestamp: posApproaching.timestamp,
        ),
      ];

      const exporter = RouteExporter();
      final gpxContent = exporter.exportGpx(trackPoints: trackPoints, waypoints: waypoints);
      expect(gpxContent, contains('<gpx version="1.1"'));
      expect(gpxContent, contains('Radar Móvel Marcado'));

      final kmlContent = exporter.exportKml(trackPoints: trackPoints, waypoints: waypoints);
      expect(kmlContent, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
      expect(kmlContent, contains('Radar Móvel Marcado'));
    });
  });
}
