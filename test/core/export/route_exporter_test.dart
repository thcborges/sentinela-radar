import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/export/route_exporter.dart';

void main() {
  group('RouteExporter (BDD - Exportação de Trajetos em GPX 1.1 e KML 2.2)', () {
    late Directory tempDir;
    late RouteExporter exporter;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sentinela_export_test_');
      exporter = const RouteExporter();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final testTrackPoints = [
      TrackPoint(
        latitude: -23.55052,
        longitude: -46.633308,
        altitude: 760.0,
        speedKmh: 60.0,
        timestamp: DateTime.utc(2026, 10, 30, 10, 0, 0),
      ),
      TrackPoint(
        latitude: -23.55152,
        longitude: -46.634308,
        altitude: 762.5,
        speedKmh: 75.0,
        timestamp: DateTime.utc(2026, 10, 30, 10, 0, 10),
      ),
    ];

    final testWaypoints = [
      PassageWaypoint(
        name: 'Radar Fixo Av. Paulista',
        latitude: -23.55100,
        longitude: -46.63380,
        speedKmh: 58.0,
        speedLimit: 60,
        isOverSpeed: false,
        timestamp: DateTime.utc(2026, 10, 30, 10, 0, 5),
        description: 'Velocidade dentro do limite da via.',
      ),
      PassageWaypoint(
        name: 'Pórtico Free Flow Km 18',
        latitude: -23.55200,
        longitude: -46.63500,
        speedKmh: 85.0,
        speedLimit: 80,
        isOverSpeed: true,
        timestamp: DateTime.utc(2026, 10, 30, 10, 0, 15),
        description: 'Excesso de velocidade registrado.',
      ),
    ];

    test('deve gerar string XML GPX 1.1 válida contendo metadados, waypoints e track points', () {
      final gpx = exporter.exportGpx(
        routeName: 'Viagem Teste SP',
        trackPoints: testTrackPoints,
        waypoints: testWaypoints,
      );

      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1"'));
      expect(gpx, contains('creator="Sentinela Radar"'));
      expect(gpx, contains('<name>Viagem Teste SP</name>'));

      // Verifica waypoints
      expect(gpx, contains('<wpt lat="-23.551" lon="-46.6338">'));
      expect(gpx, contains('<name>Radar Fixo Av. Paulista</name>'));
      expect(gpx, contains('<desc>Velocidade dentro do limite da via.</desc>'));
      expect(gpx, contains('<type>PassageCompliant</type>'));
      expect(gpx, contains('<type>PassageOverSpeed</type>'));

      // Verifica track points
      expect(gpx, contains('<trk>'));
      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('<trkpt lat="-23.55052" lon="-46.633308">'));
      expect(gpx, contains('<ele>760.0</ele>'));
      expect(gpx, contains('<time>2026-10-30T10:00:00.000Z</time>'));
      expect(gpx, contains('<speed>16.67</speed>')); // 60 km/h convertido para m/s no GPX
    });

    test('deve gerar string XML KML 2.2 válida com estilos, coordenadas e placemarks', () {
      final kml = exporter.exportKml(
        routeName: 'Trajeto Rodovia SP-070',
        trackPoints: testTrackPoints,
        waypoints: testWaypoints,
      );

      expect(kml, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(kml, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
      expect(kml, contains('<name>Trajeto Rodovia SP-070</name>'));

      // Estilos M3 de cores semânticas
      expect(kml, contains('<Style id="compliantPoint">'));
      expect(kml, contains('<Style id="overSpeedPoint">'));
      expect(kml, contains('<Style id="routePath">'));

      // Placemarks de passagens
      expect(kml, contains('<Placemark>'));
      expect(kml, contains('<name>Radar Fixo Av. Paulista</name>'));
      expect(kml, contains('#compliantPoint'));
      expect(kml, contains('<name>Pórtico Free Flow Km 18</name>'));
      expect(kml, contains('#overSpeedPoint'));

      // LineString com sequência de coordenadas lon,lat,alt
      expect(kml, contains('<LineString>'));
      expect(kml, contains('<coordinates>'));
      expect(kml, contains('-46.633308,-23.55052,760.0'));
      expect(kml, contains('-46.634308,-23.55152,762.5'));
    });

    test('deve salvar GPX e KML diretamente em arquivos no disco', () async {
      final gpxFile = File('${tempDir.path}/export_test.gpx');
      final kmlFile = File('${tempDir.path}/export_test.kml');

      final savedGpx = await exporter.saveGpxToFile(
        file: gpxFile,
        routeName: 'Disco GPX',
        trackPoints: testTrackPoints,
        waypoints: testWaypoints,
      );

      final savedKml = await exporter.saveKmlToFile(
        file: kmlFile,
        routeName: 'Disco KML',
        trackPoints: testTrackPoints,
        waypoints: testWaypoints,
      );

      expect(await savedGpx.exists(), isTrue);
      expect(await savedKml.exists(), isTrue);

      final gpxContent = await savedGpx.readAsString();
      final kmlContent = await savedKml.readAsString();

      expect(gpxContent, contains('<gpx version="1.1"'));
      expect(kmlContent, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
    });

    test('deve tratar adequadamente listas vazias de waypoints e track points', () {
      final emptyGpx = exporter.exportGpx(routeName: 'Vazio');
      expect(emptyGpx, contains('<gpx version="1.1"'));
      expect(emptyGpx, isNot(contains('<wpt')));
      expect(emptyGpx, isNot(contains('<trkseg>')));

      final emptyKml = exporter.exportKml(routeName: 'Vazio');
      expect(emptyKml, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
      expect(emptyKml, isNot(contains('<LineString>')));
    });
  });
}
