import 'dart:convert';
import 'dart:io';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sqlite3/sqlite3.dart';

/// Serviço utilitário responsável pela exportação e compilação de conjuntos
/// de dados nacionais nos formatos CSV, JSON e SQLite com extensão espacial R*Tree.
class DatasetExporter {
  const DatasetExporter();

  /// Exporta uma lista de POIs para formato CSV tabular padronizado.
  String exportToCsv(List<PoiPoint> pois) {
    final buffer = StringBuffer();
    buffer.writeln(
      'id,latitude,longitude,type,speed_limit,direction,tolerance_angle,road_name,toll_fee_car,operator,city,state,source',
    );

    for (final poi in pois) {
      final roadNameEscaped = _escapeCsvField(poi.roadName);
      final operatorEscaped = _escapeCsvField(poi.operator ?? '');
      final cityEscaped = _escapeCsvField(poi.city ?? '');
      final stateEscaped = _escapeCsvField(poi.state ?? '');
      final sourceEscaped = _escapeCsvField(poi.source ?? '');

      buffer.writeln([
        poi.id,
        poi.latitude.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), ''),
        poi.longitude.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), ''),
        poi.type.name,
        poi.speedLimit ?? '',
        poi.direction ?? '',
        poi.toleranceAngle.toStringAsFixed(1),
        roadNameEscaped,
        poi.tollFeeCar != null ? poi.tollFeeCar.toString() : '',
        operatorEscaped,
        cityEscaped,
        stateEscaped,
        sourceEscaped,
      ].join(','));
    }

    return buffer.toString().trimRight();
  }

  /// Exporta uma lista de POIs para formato JSON compatível com o sincronizador in-app.
  String exportToJson(List<PoiPoint> pois, {bool pretty = false}) {
    final elements = pois.map((p) {
      final tags = <String, dynamic>{
        'name': p.roadName,
        'type': p.type.name,
      };
      if (p.speedLimit != null) tags['maxspeed'] = p.speedLimit.toString();
      if (p.direction != null) tags['direction'] = p.direction.toString();
      if (p.operator != null && p.operator!.isNotEmpty) tags['operator'] = p.operator;
      if (p.city != null && p.city!.isNotEmpty) tags['city'] = p.city;
      if (p.state != null && p.state!.isNotEmpty) tags['state'] = p.state;
      if (p.source != null && p.source!.isNotEmpty) tags['source'] = p.source;
      if (p.tollFeeCar != null) tags['toll_fee_car'] = p.tollFeeCar.toString();

      return {
        'type': 'node',
        'id': p.id,
        'lat': p.latitude,
        'lon': p.longitude,
        'tags': tags,
      };
    }).toList();

    final payload = {'elements': elements};
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(payload);
    }
    return jsonEncode(payload);
  }

  /// Compila o banco SQLite com extensão R*Tree e insere os POIs em lote com transação atômica.
  int exportToSqliteDb({
    required String targetPath,
    required List<PoiPoint> pois,
    DateTime? lastUpdated,
    String source = 'OpenStreetMap / Dados Abertos Brasil',
  }) {
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    } else {
      targetFile.parent.createSync(recursive: true);
    }

    final rawDb = sqlite3.open(targetPath);
    final dbManager = DatabaseManager(rawDb);
    dbManager.initializeSchema();

    if (pois.isNotEmpty) {
      dbManager.insertPoisBatch(pois);
    }

    final updateTime = lastUpdated ?? DateTime.now().toUtc();
    dbManager.setMetadata('total_count', pois.length.toString());
    dbManager.setMetadata('last_updated', updateTime.toIso8601String());
    dbManager.setMetadata('source', source);
    dbManager.setMetadata('schema_version', '1');

    rawDb.close();
    return pois.length;
  }

  /// Cria uma base inicial limpa (clean install) contendo as tabelas e metadados zerados.
  void createCleanDatabase({required String targetPath}) {
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    } else {
      targetFile.parent.createSync(recursive: true);
    }

    final rawDb = sqlite3.open(targetPath);
    final dbManager = DatabaseManager(rawDb);
    dbManager.initializeSchema();
    dbManager.setMetadata('total_count', '0');
    dbManager.setMetadata('last_updated', '');
    dbManager.setMetadata('source', 'Sentinela Clean Seed');
    dbManager.setMetadata('schema_version', '1');
    rawDb.close();
  }

  String _escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
