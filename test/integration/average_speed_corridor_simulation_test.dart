import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/section_control_machine.dart';
import 'package:sentinela/core/export/route_exporter.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/security/database_integrity_validator.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';
import 'package:sentinela/features/stats/repository/passage_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('Simulação de Integração Hermética: Radar de Trecho, Integridade SHA-256 e Exportação GPX/KML', () {
    late Directory tempDir;
    late Database db;
    late PassageRepository passageRepo;
    late DatabaseIntegrityValidator integrityValidator;
    late RouteExporter routeExporter;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sentinela_corridor_sim_');
      final dbPath = '${tempDir.path}/sim_sentinela.db';
      db = sqlite3.open(dbPath);
      passageRepo = PassageRepository(db)..initSchema();
      integrityValidator = const DatabaseIntegrityValidator();
      routeExporter = const RouteExporter();
    });

    tearDown(() {
      db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Travessia completa de trecho de velocidade média com desaceleração defensiva e exportação', () async {
      // 1. Definição do Pórtico A (Entrada) e Pórtico B (Saída)
      // Trecho de ~1.5 km em linha reta rumo Norte (bearing 0°) com limite 80 km/h
      final corridor = AverageSpeedCorridor.fromCoordinates(
        id: 'corridor_sp_070_km15',
        name: 'SP-070 Km 15 ao Km 16.5',
        speedLimitKmh: 80,
        entryLatitude: -23.5000,
        entryLongitude: -46.6000,
        entryBearing: 0.0,
        exitLatitude: -23.4865,
        exitLongitude: -46.6000,
        exitBearing: 0.0,
      );

      final sectionMachine = SectionControlMachine(corridors: [corridor]);
      final List<TrackPoint> trackPoints = [];

      var currentTime = DateTime.utc(2026, 10, 30, 8, 0, 0);

      // 2. Condutor se aproxima e cruza o Pórtico A a 100 km/h
      final p1 = VehiclePosition(
        latitude: -23.5001,
        longitude: -46.6000,
        speedKmh: 100.0,
        bearing: 0.0,
        accuracyMeters: 4.0,
        timestamp: currentTime,
      );
      trackPoints.add(TrackPoint(
        latitude: p1.latitude,
        longitude: p1.longitude,
        speedKmh: p1.speedKmh,
        timestamp: p1.timestamp,
      ));

      var result = sectionMachine.updatePosition(p1);
      expect(result, isNull); // Em trânsito, ainda não concluído
      expect(sectionMachine.state.isActive, isTrue);

      // 3. Condutor acelera dentro do trecho por 30 segundos percorrendo ~833m a 100 km/h
      currentTime = currentTime.add(const Duration(seconds: 30));
      final p2 = VehiclePosition(
        latitude: -23.4925,
        longitude: -46.6000,
        speedKmh: 100.0,
        bearing: 0.0,
        accuracyMeters: 4.0,
        timestamp: currentTime,
      );
      trackPoints.add(TrackPoint(
        latitude: p2.latitude,
        longitude: p2.longitude,
        speedKmh: p2.speedKmh,
        timestamp: p2.timestamp,
      ));

      result = sectionMachine.updatePosition(p2);
      expect(result, isNull);
      expect(sectionMachine.state.isActive, isTrue);
      expect(sectionMachine.state.isOverSpeed, isTrue); // Média de ~100 km/h supera limite de 80 km/h
      expect(sectionMachine.state.targetRemainingSeconds, greaterThan(0));

      // 4. Condutor visualiza o alerta Sentinela e reduz velocidade para 50 km/h
      // Percorre os ~667m restantes em 48 segundos (50 km/h = 13.88 m/s * 48s = 666m)
      currentTime = currentTime.add(const Duration(seconds: 48));
      final p3 = VehiclePosition(
        latitude: -23.4864,
        longitude: -46.6000,
        speedKmh: 50.0,
        bearing: 0.0,
        accuracyMeters: 4.0,
        timestamp: currentTime,
      );
      trackPoints.add(TrackPoint(
        latitude: p3.latitude,
        longitude: p3.longitude,
        speedKmh: p3.speedKmh,
        timestamp: p3.timestamp,
      ));

      result = sectionMachine.updatePosition(p3);
      // Ao alcançar Pórtico B com tempo total de 78s para 1500m (média = 1500/78 * 3.6 = 69.2 km/h < 80 km/h)
      expect(result, isNotNull);
      expect(result!.isCompleted, isTrue);
      expect(result.averageSpeedKmh, lessThanOrEqualTo(80.0));
      expect(result.isOverSpeed, isFalse);

      // 5. Registra passagem conforme no histórico offline local
      final passageId = await passageRepo.insertPassage(PassageRecord(
        poiId: 9901,
        poiType: PoiType.fixedRadar,
        vehicleSpeedKmh: result.averageSpeedKmh,
        speedLimit: 80,
        timestamp: currentTime,
        isOverSpeed: result.isOverSpeed,
        roadName: corridor.name,
        latitude: p3.latitude,
        longitude: p3.longitude,
      ));
      expect(passageId, greaterThan(0));

      final passages = await passageRepo.getRecentPassages();
      expect(passages.length, equals(1));
      expect(passages.first.isOverSpeed, isFalse);

      // 6. Exportação do trajeto e passagens em GPX 1.1 e KML 2.2
      final waypoints = passages.map((p) => PassageWaypoint(
        name: p.roadName,
        latitude: p.latitude!,
        longitude: p.longitude!,
        speedKmh: p.vehicleSpeedKmh,
        speedLimit: p.speedLimit,
        isOverSpeed: p.isOverSpeed,
        timestamp: p.timestamp,
      )).toList();

      final gpxString = routeExporter.exportGpx(
        routeName: 'Simulação Trecho SP-070',
        trackPoints: trackPoints,
        waypoints: waypoints,
      );
      expect(gpxString, contains('<gpx version="1.1"'));
      expect(gpxString, contains('Simulação Trecho SP-070'));
      expect(gpxString, contains('<type>PassageCompliant</type>'));
      expect(gpxString, contains('<trkpt lat="-23.5001" lon="-46.6">'));

      final kmlString = routeExporter.exportKml(
        routeName: 'Simulação Trecho SP-070',
        trackPoints: trackPoints,
        waypoints: waypoints,
      );
      expect(kmlString, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
      expect(kmlString, contains('#compliantPoint'));
      expect(kmlString, contains('<LineString>'));

      // 7. Validação Criptográfica de Integridade da Base (SHA-256 e PRAGMA integrity_check)
      final dbFile = File('${tempDir.path}/sim_sentinela.db');
      final validation = await integrityValidator.validateDatabase(dbFile: dbFile);
      expect(validation.isValid, isTrue);
      expect(validation.sha256Hash.length, equals(64));
      expect(validation.isSqliteIntegrityValid, isTrue);
    });
  });
}
