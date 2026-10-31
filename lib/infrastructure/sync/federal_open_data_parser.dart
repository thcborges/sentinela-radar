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

      final header = lines.first.split(',').map((e) => e.trim().toLowerCase()).toList();
      final idIdx = header.indexOf('id');
      final ufIdx = header.indexOf('uf');
      final rodoviaIdx = header.indexOf('rodovia');
      final kmIdx = header.indexOf('km');
      final munIdx = header.indexOf('municipio');
      final tipoIdx = header.indexOf('tipo_equipamento');
      final velIdx = header.indexOf('velocidade_regulamentada');
      final latIdx = header.indexOf('latitude');
      final lonIdx = header.indexOf('longitude');
      final sentidoIdx = header.indexOf('sentido');

      if (latIdx == -1 || lonIdx == -1) return [];

      final pois = <PoiPoint>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = line.split(',').map((e) => e.trim()).toList();
        if (cols.length <= latIdx || cols.length <= lonIdx) continue;

        final rawId = idIdx != -1 && idIdx < cols.length ? int.tryParse(cols[idIdx]) : null;
        final id = rawId ?? (100000 + i);

        final lat = double.tryParse(cols[latIdx]);
        final lon = double.tryParse(cols[lonIdx]);
        if (lat == null || lon == null) continue;

        final uf = ufIdx != -1 && ufIdx < cols.length ? cols[ufIdx] : null;
        final rodovia = rodoviaIdx != -1 && rodoviaIdx < cols.length ? cols[rodoviaIdx] : '';
        final km = kmIdx != -1 && kmIdx < cols.length ? cols[kmIdx] : '';
        final mun = munIdx != -1 && munIdx < cols.length ? cols[munIdx] : null;
        final tipoStr = tipoIdx != -1 && tipoIdx < cols.length ? cols[tipoIdx] : '';
        final vel = velIdx != -1 && velIdx < cols.length ? int.tryParse(cols[velIdx]) : null;
        final sentido = sentidoIdx != -1 && sentidoIdx < cols.length ? cols[sentidoIdx] : null;

        final poiType = _classifyDnitType(tipoStr);
        final roadName = km.isNotEmpty ? '$rodovia km $km'.trim() : rodovia;
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

      final header = lines.first.split(',').map((e) => e.trim().toLowerCase()).toList();
      final idIdx = header.indexOf('id');
      final concIdx = header.indexOf('concessionaria');
      final rodoviaIdx = header.indexOf('rodovia');
      final kmIdx = header.indexOf('km');
      final munIdx = header.indexOf('municipio');
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
        final cols = line.split(',').map((e) => e.trim()).toList();
        if (cols.length <= latIdx || cols.length <= lonIdx) continue;

        final rawId = idIdx != -1 && idIdx < cols.length ? int.tryParse(cols[idIdx]) : null;
        final id = rawId ?? (200000 + i);

        final lat = double.tryParse(cols[latIdx]);
        final lon = double.tryParse(cols[lonIdx]);
        if (lat == null || lon == null) continue;

        final conc = concIdx != -1 && concIdx < cols.length ? cols[concIdx] : null;
        final rodovia = rodoviaIdx != -1 && rodoviaIdx < cols.length ? cols[rodoviaIdx] : '';
        final km = kmIdx != -1 && kmIdx < cols.length ? cols[kmIdx] : '';
        final mun = munIdx != -1 && munIdx < cols.length ? cols[munIdx] : null;
        final uf = ufIdx != -1 && ufIdx < cols.length ? cols[ufIdx] : null;
        final tipoStr = tipoIdx != -1 && tipoIdx < cols.length ? cols[tipoIdx] : '';
        final tarifa = tarifaIdx != -1 && tarifaIdx < cols.length ? double.tryParse(cols[tarifaIdx]) : null;

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
    final id = rec['_id'] as int? ?? rec['id'] as int? ?? 0;
    final lat = (rec['latitude'] as num?)?.toDouble();
    final lon = (rec['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    final tipoStr = (rec['tipo_equipamento'] as String?) ?? '';
    final vel = rec['velocidade_regulamentada'] as int?;
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
    final id = rec['id'] as int? ?? rec['_id'] as int? ?? 0;
    final lat = (rec['latitude'] as num?)?.toDouble();
    final lon = (rec['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    final tipoStr = (rec['tipo_praca'] as String?) ?? '';
    final tarifa = (rec['tarifa_carro'] as num?)?.toDouble() ?? (rec['tarifa_eixo_1'] as num?)?.toDouble();
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

  static PoiType _classifyDnitType(String tipo) {
    final lower = tipo.toLowerCase();
    if (lower.contains('redutor') || lower.contains('lombada')) {
      return PoiType.electronicSpeedBump;
    }
    return PoiType.fixedRadar;
  }
}
