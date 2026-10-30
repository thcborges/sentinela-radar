import 'dart:io';

/// Ponto de rastro/trajetória de GPS para exportação.
class TrackPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedKmh;
  final DateTime timestamp;

  const TrackPoint({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    required this.speedKmh,
    required this.timestamp,
  });

  /// Velocidade em metros por segundo (padrão GPX).
  double get speedMs => speedKmh / 3.6;
}

/// Marcador ou waypoint de passagem por ponto fiscalizado.
class PassageWaypoint {
  final String name;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final int? speedLimit;
  final bool isOverSpeed;
  final DateTime timestamp;
  final String description;

  const PassageWaypoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    this.speedLimit,
    required this.isOverSpeed,
    required this.timestamp,
    this.description = '',
  });
}

/// Exportador de trajetos e histórico de passagens em padrões abertos GPX 1.1 e KML 2.2.
///
/// Opera 100% offline e hermético sem qualquer transmissão externa de telemetria.
class RouteExporter {
  const RouteExporter();

  /// Gera representação XML em conformidade com o padrão GPX 1.1.
  String exportGpx({
    String routeName = 'Trajeto Sentinela',
    List<TrackPoint> trackPoints = const [],
    List<PassageWaypoint> waypoints = const [],
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Sentinela Radar" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>$routeName</name>');
    buffer.writeln('    <time>${DateTime.now().toUtc().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');

    // Waypoints de passagens
    for (final wpt in waypoints) {
      final typeStr = wpt.isOverSpeed ? 'PassageOverSpeed' : 'PassageCompliant';
      buffer.writeln('  <wpt lat="${wpt.latitude}" lon="${wpt.longitude}">');
      buffer.writeln('    <name>${_xmlEscape(wpt.name)}</name>');
      if (wpt.description.isNotEmpty) {
        buffer.writeln('    <desc>${_xmlEscape(wpt.description)}</desc>');
      }
      buffer.writeln('    <time>${wpt.timestamp.toUtc().toIso8601String()}</time>');
      buffer.writeln('    <type>$typeStr</type>');
      buffer.writeln('  </wpt>');
    }

    // Trajeto contínuo (Track)
    if (trackPoints.isNotEmpty) {
      buffer.writeln('  <trk>');
      buffer.writeln('    <name>$routeName</name>');
      buffer.writeln('    <trkseg>');
      for (final pt in trackPoints) {
        buffer.writeln('      <trkpt lat="${pt.latitude}" lon="${pt.longitude}">');
        buffer.writeln('        <ele>${pt.altitude}</ele>');
        buffer.writeln('        <time>${pt.timestamp.toUtc().toIso8601String()}</time>');
        buffer.writeln('        <speed>${pt.speedMs.toStringAsFixed(2)}</speed>');
        buffer.writeln('      </trkpt>');
      }
      buffer.writeln('    </trkseg>');
      buffer.writeln('  </trk>');
    }

    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  /// Gera representação XML em conformidade com o padrão OGC KML 2.2.
  String exportKml({
    String routeName = 'Trajeto Sentinela',
    List<TrackPoint> trackPoints = const [],
    List<PassageWaypoint> waypoints = const [],
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>$routeName</name>');

    // Definição de Estilos M3
    buffer.writeln('    <Style id="compliantPoint">');
    buffer.writeln('      <IconStyle>');
    buffer.writeln('        <color>ff00e676</color>'); // Verde M3
    buffer.writeln('        <scale>1.1</scale>');
    buffer.writeln('      </IconStyle>');
    buffer.writeln('    </Style>');

    buffer.writeln('    <Style id="overSpeedPoint">');
    buffer.writeln('      <IconStyle>');
    buffer.writeln('        <color>ff5252ff</color>'); // Vermelho M3
    buffer.writeln('        <scale>1.2</scale>');
    buffer.writeln('      </IconStyle>');
    buffer.writeln('    </Style>');

    buffer.writeln('    <Style id="routePath">');
    buffer.writeln('      <LineStyle>');
    buffer.writeln('        <color>ff00d4ff</color>'); // Ciano / Azul HUD
    buffer.writeln('        <width>4</width>');
    buffer.writeln('      </LineStyle>');
    buffer.writeln('    </Style>');

    // Waypoints / Placemarks
    for (final wpt in waypoints) {
      final styleId = wpt.isOverSpeed ? '#overSpeedPoint' : '#compliantPoint';
      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>${_xmlEscape(wpt.name)}</name>');
      buffer.writeln('      <description>${_xmlEscape(wpt.description)}</description>');
      buffer.writeln('      <styleUrl>$styleId</styleUrl>');
      buffer.writeln('      <Point>');
      buffer.writeln('        <coordinates>${wpt.longitude},${wpt.latitude},0</coordinates>');
      buffer.writeln('      </Point>');
      buffer.writeln('    </Placemark>');
    }

    // Traçado contínuo (LineString)
    if (trackPoints.isNotEmpty) {
      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>$routeName - Percurso</name>');
      buffer.writeln('      <styleUrl>#routePath</styleUrl>');
      buffer.writeln('      <LineString>');
      buffer.writeln('        <tessellate>1</tessellate>');
      buffer.writeln('        <coordinates>');
      final coordsStr = trackPoints
          .map((p) => '${p.longitude},${p.latitude},${p.altitude}')
          .join(' ');
      buffer.writeln('          $coordsStr');
      buffer.writeln('        </coordinates>');
      buffer.writeln('      </LineString>');
      buffer.writeln('    </Placemark>');
    }

    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');
    return buffer.toString();
  }

  /// Salva o trajeto gerado em arquivo GPX no disco.
  Future<File> saveGpxToFile({
    required File file,
    String routeName = 'Trajeto Sentinela',
    List<TrackPoint> trackPoints = const [],
    List<PassageWaypoint> waypoints = const [],
  }) async {
    final content = exportGpx(
      routeName: routeName,
      trackPoints: trackPoints,
      waypoints: waypoints,
    );
    return file.writeAsString(content);
  }

  /// Salva o trajeto gerado em arquivo KML no disco.
  Future<File> saveKmlToFile({
    required File file,
    String routeName = 'Trajeto Sentinela',
    List<TrackPoint> trackPoints = const [],
    List<PassageWaypoint> waypoints = const [],
  }) async {
    final content = exportKml(
      routeName: routeName,
      trackPoints: trackPoints,
      waypoints: waypoints,
    );
    return file.writeAsString(content);
  }

  String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
