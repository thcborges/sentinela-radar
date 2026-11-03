import 'dart:convert';
import '../../domain/models/poi_model.dart';

/// Parser dedicado para ingestão e conversão de dados abertos governamentais
/// (DNIT - PNCV e ANTT - Concessões e Free Flow) no modelo nativo do Sentinela.
class FederalOpenDataParser {
  /// Converte JSON CKAN do DNIT PNCV em lista de [PoiPoint].
  static List<PoiPoint> parseDnitJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final result = decoded['result'] as Map<String, dynamic>?;
      if (result == null) return [];

      final records = result['records'] as List<dynamic>?;
      if (records == null) return [];

      final pois = <PoiPoint>[];
      for (final rec in records) {
        if (rec is! Map<String, dynamic>) continue;
        final poi = _mapDnitRecord(rec);
        if (poi != null) {
          pois.add(poi);
        }
      }
      return pois;
    } catch (_) {
      return [];
    }
  }

  /// Converte CSV do DNIT PNCV em lista de [PoiPoint].
  static List<PoiPoint> parseDnitCsv(String csvString) {
    try {
      final lines = const LineSplitter().convert(csvString);
      if (lines.length < 2) return [];

      final delimiter = _detectDelimiter(lines.first);
      final header = _splitCsvLine(lines.first, delimiter).map((e) => e.toLowerCase()).toList();
      var idIdx = header.indexOf('id');
      if (idIdx == -1) {
        idIdx = header.indexWhere((h) => h.contains('código') || h.contains('codigo') || h.contains('identifica'));
      }
      final ufIdx = header.indexOf('uf');
      final rodoviaIdx = header.indexOf('rodovia');
      final kmIdx = header.indexOf('km');
      var munIdx = header.indexOf('municipio');
      if (munIdx == -1) {
        munIdx = header.indexWhere((h) => h.contains('munic'));
      }
      var tipoIdx = header.indexOf('tipo_equipamento');
      if (tipoIdx == -1) {
        tipoIdx = header.indexOf('tipo');
      }
      final velIdx = header.indexOf('velocidade_regulamentada');
      var latIdx = header.indexOf('latitude');
      var lonIdx = header.indexOf('longitude');
      final coordIdx = header.indexWhere((h) => h.contains('coordenadas') || h.contains('lat/long'));
      final sentidoIdx = header.indexOf('sentido');

      if ((latIdx == -1 || lonIdx == -1) && coordIdx == -1) return [];

      final pois = <PoiPoint>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = _splitCsvLine(line, delimiter);

        double? lat;
        double? lon;

        if (coordIdx != -1 && cols.length > coordIdx) {
          final coordStr = cols[coordIdx];
          final parts = coordStr.split(RegExp(r'[/]'));
          if (parts.length >= 2) {
            lat = _parseDouble(parts[0]);
            lon = _parseDouble(parts[1]);
          }
        }
        if (lat == null && latIdx != -1 && cols.length > latIdx) {
          lat = _parseDouble(cols[latIdx]);
        }
        if (lon == null && lonIdx != -1 && cols.length > lonIdx) {
          lon = _parseDouble(cols[lonIdx]);
        }
        if (lat == null || lon == null) continue;

        final rawId = idIdx != -1 && idIdx < cols.length ? _parseInt(cols[idIdx]) : null;
        final id = rawId ?? (100000 + i);

        final uf = ufIdx != -1 && ufIdx < cols.length ? cols[ufIdx] : null;
        final rodovia = rodoviaIdx != -1 && rodoviaIdx < cols.length ? cols[rodoviaIdx] : '';
        final km = kmIdx != -1 && kmIdx < cols.length ? cols[kmIdx] : '';
        final mun = munIdx != -1 && munIdx < cols.length ? cols[munIdx] : null;
        final tipoStr = tipoIdx != -1 && tipoIdx < cols.length ? cols[tipoIdx] : '';
        final vel = velIdx != -1 && velIdx < cols.length ? _parseInt(cols[velIdx]) : null;
        final sentido = sentidoIdx != -1 && sentidoIdx < cols.length ? cols[sentidoIdx] : null;

        final poiType = _classifyDnitType(tipoStr);
        var formattedRoad = rodovia;
        if (RegExp(r'^\d+$').hasMatch(rodovia)) {
          formattedRoad = 'BR-$rodovia';
        }
        final cleanKm = km.replaceAll(',', '.');
        final roadName = cleanKm.isNotEmpty ? '$formattedRoad km $cleanKm'.trim() : formattedRoad;
        final toleranceAngle = (sentido != null && sentido.toLowerCase().contains('ambos')) ? 180.0 : 35.0;

        pois.add(PoiPoint(
          id: id,
          type: poiType,
          latitude: lat,
          longitude: lon,
          speedLimit: vel,
          toleranceAngle: toleranceAngle,
          roadName: roadName,
          city: mun,
          state: uf,
          source: 'DNIT_PNCV',
        ));
      }
      return pois;
    } catch (_) {
      return [];
    }
  }

  /// Converte JSON CKAN da ANTT em lista de [PoiPoint].
  static List<PoiPoint> parseAnttJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final result = decoded['result'] as Map<String, dynamic>?;
      final records = (result?['records'] ?? decoded['records']) as List<dynamic>?;
      if (records == null) return [];

      final pois = <PoiPoint>[];
      for (final rec in records) {
        if (rec is! Map<String, dynamic>) continue;
        final poi = _mapAnttRecord(rec);
        if (poi != null) {
          pois.add(poi);
        }
      }
      return pois;
    } catch (_) {
      return [];
    }
  }

  /// Converte CSV da ANTT em lista de [PoiPoint].
  static List<PoiPoint> parseAnttCsv(String csvString) {
    try {
      final lines = const LineSplitter().convert(csvString);
      if (lines.length < 2) return [];

      final delimiter = _detectDelimiter(lines.first);
      final header = _splitCsvLine(lines.first, delimiter).map((e) => e.toLowerCase()).toList();
      final idIdx = header.indexOf('id');
      final concIdx = header.indexOf('concessionaria');
      final rodoviaIdx = header.indexOf('rodovia');
      final kmIdx = header.indexOf('km');
      var munIdx = header.indexOf('municipio');
      if (munIdx == -1) {
        munIdx = header.indexWhere((h) => h.contains('munic'));
      }
      final ufIdx = header.indexOf('uf');
      final tipoIdx = header.indexOf('tipo_praca');
      final tarifaIdx = header.indexOf('tarifa_carro');
      final latIdx = header.indexOf('latitude');
      final lonIdx = header.indexOf('longitude');

      if (latIdx == -1 || lonIdx == -1) return [];

      final pois = <PoiPoint>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = _splitCsvLine(line, delimiter);
        if (cols.length <= latIdx || cols.length <= lonIdx) continue;

        final rawId = idIdx != -1 && idIdx < cols.length ? _parseInt(cols[idIdx]) : null;
        final id = rawId ?? (200000 + i);

        final lat = _parseDouble(cols[latIdx]);
        final lon = _parseDouble(cols[lonIdx]);
        if (lat == null || lon == null) continue;

        final conc = concIdx != -1 && concIdx < cols.length ? cols[concIdx] : null;
        final rodovia = rodoviaIdx != -1 && rodoviaIdx < cols.length ? cols[rodoviaIdx] : '';
        final km = kmIdx != -1 && kmIdx < cols.length ? cols[kmIdx] : '';
        final mun = munIdx != -1 && munIdx < cols.length ? cols[munIdx] : null;
        final uf = ufIdx != -1 && ufIdx < cols.length ? cols[ufIdx] : null;
        final tipoStr = tipoIdx != -1 && tipoIdx < cols.length ? cols[tipoIdx] : '';
        final tarifa = tarifaIdx != -1 && tarifaIdx < cols.length ? _parseDouble(cols[tarifaIdx]) : null;

        final isFreeFlow = tipoStr.toLowerCase().contains('free') || tipoStr.toLowerCase().contains('pórtico');
        final poiType = isFreeFlow ? PoiType.freeFlowToll : PoiType.tollBooth;
        final roadName = km.isNotEmpty ? '$rodovia km $km'.trim() : rodovia;

        pois.add(PoiPoint(
          id: id,
          type: poiType,
          latitude: lat,
          longitude: lon,
          toleranceAngle: 180.0,
          roadName: roadName,
          tollFeeCar: tarifa,
          operator: conc,
          city: mun,
          state: uf,
          source: 'ANTT',
        ));
      }
      return pois;
    } catch (_) {
      return [];
    }
  }

  static PoiPoint? _mapDnitRecord(Map<String, dynamic> rec) {
    final id = _parseInt(rec['_id']) ?? _parseInt(rec['id']) ?? 0;
    final lat = _parseDouble(rec['latitude']);
    final lon = _parseDouble(rec['longitude']);
    if (lat == null || lon == null) return null;

    final tipoStr = (rec['tipo_equipamento'] as String?) ?? '';
    final vel = _parseInt(rec['velocidade_regulamentada']);
    final uf = rec['uf'] as String?;
    final rodovia = (rec['rodovia'] as String?) ?? '';
    final km = rec['km']?.toString() ?? '';
    final mun = rec['municipio'] as String?;
    final sentido = (rec['sentido'] as String?) ?? '';

    final poiType = _classifyDnitType(tipoStr);
    final roadName = km.isNotEmpty ? '$rodovia km $km'.trim() : rodovia;
    final toleranceAngle = sentido.toLowerCase().contains('ambos') ? 180.0 : 35.0;

    return PoiPoint(
      id: id,
      type: poiType,
      latitude: lat,
      longitude: lon,
      speedLimit: vel,
      toleranceAngle: toleranceAngle,
      roadName: roadName,
      city: mun,
      state: uf,
      source: 'DNIT_PNCV',
    );
  }

  static PoiPoint? _mapAnttRecord(Map<String, dynamic> rec) {
    final id = _parseInt(rec['id']) ?? _parseInt(rec['_id']) ?? 0;
    final lat = _parseDouble(rec['latitude']);
    final lon = _parseDouble(rec['longitude']);
    if (lat == null || lon == null) return null;

    final tipoStr = (rec['tipo_praca'] as String?) ?? '';
    final tarifa = _parseDouble(rec['tarifa_carro']) ?? _parseDouble(rec['tarifa_eixo_1']);
    final conc = rec['concessionaria'] as String?;
    final rodovia = (rec['rodovia'] as String?) ?? '';
    final km = rec['km']?.toString() ?? '';
    final mun = rec['municipio'] as String?;
    final uf = rec['uf'] as String?;

    final isFreeFlow = tipoStr.toLowerCase().contains('free') || tipoStr.toLowerCase().contains('pórtico');
    final poiType = isFreeFlow ? PoiType.freeFlowToll : PoiType.tollBooth;
    final roadName = km.isNotEmpty ? '$rodovia km $km'.trim() : rodovia;

    return PoiPoint(
      id: id,
      type: poiType,
      latitude: lat,
      longitude: lon,
      toleranceAngle: 180.0,
      roadName: roadName,
      tollFeeCar: tarifa,
      operator: conc,
      city: mun,
      state: uf,
      source: 'ANTT',
    );
  }

  static String _detectDelimiter(String headerLine) {
    if (headerLine.contains(';')) return ';';
    return ',';
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    if (!line.contains('"')) {
      return line.split(delimiter).map((e) => e.trim()).toList();
    }
    final result = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes && line.startsWith(delimiter, i)) {
        result.add(sb.toString().trim());
        sb.clear();
        i += delimiter.length - 1;
      } else {
        sb.write(char);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll('"', '').replaceAll("'", '').trim().replaceAll(',', '.');
      if (sanitized.isEmpty) return null;
      return double.tryParse(sanitized);
    }
    return double.tryParse(value.toString().replaceAll(',', '.').trim());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final sanitized = value.replaceAll('"', '').replaceAll("'", '').trim().replaceAll(',', '.');
      if (sanitized.isEmpty) return null;
      final parsedInt = int.tryParse(sanitized);
      if (parsedInt != null) return parsedInt;
      return double.tryParse(sanitized)?.round();
    }
    return int.tryParse(value.toString()) ?? double.tryParse(value.toString().replaceAll(',', '.'))?.round();
  }

  static PoiType _classifyDnitType(String tipo) {
    final lower = tipo.toLowerCase().trim();
    if (lower == 'rev' || lower.contains('redutor') || lower.contains('lombada')) {
      return PoiType.electronicSpeedBump;
    }
    if (lower == 'cem' || lower.contains('misto') || lower.contains('semaforo') || lower.contains('semáforo')) {
      return PoiType.trafficLightRadar;
    }
    return PoiType.fixedRadar;
  }
}
