import 'dart:math' as math;
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/domain/math/bearing.dart';
import 'package:sentinela/domain/math/haversine.dart';
import 'package:sqlite3/sqlite3.dart';

/// Construtor e orquestrador de ingestão multi-fonte de radares e pontos de interesse (POIs).
///
/// Salva os dados brutos de cada fonte oficial/aberta em tabelas dedicadas
/// (`source_antt_pedagios`, `source_antt_radares`, `source_nacional_aberto`, `source_osm_comunitario`),
/// consolida todos os pontos na tabela unificada `pois` com deduplicação espacial inteligente (<35m),
/// indexa no SQLite R*Tree (`pois_index`) e registra sumários para auditoria.
class MultiSourceRadarBuilder {
  const MultiSourceRadarBuilder();

  /// Inicializa o esquema de todas as tabelas individuais de fontes e o esquema do Sentinela.
  void initializeMultiSourceSchema(Database db) {
    db.execute('PRAGMA foreign_keys = ON;');

    // 1. Tabela individual ANTT Praças de Pedágio
    db.execute('''
      CREATE TABLE IF NOT EXISTS source_antt_pedagios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concessionaria TEXT,
        praca_de_pedagio TEXT,
        rodovia TEXT,
        uf TEXT,
        km_m TEXT,
        municipio TEXT,
        tipo_de_pista TEXT,
        sentido TEXT,
        situacao TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        tarifa_automovel REAL,
        tarifa_comercial REAL,
        ingested_at TEXT NOT NULL
      );
    ''');

    // 2. Tabela individual ANTT Radares
    db.execute('''
      CREATE TABLE IF NOT EXISTS source_antt_radares (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concessionaria TEXT,
        tipo_de_radar TEXT,
        rodovia TEXT,
        uf TEXT,
        km_m TEXT,
        municipio TEXT,
        tipo_de_pista TEXT,
        sentido TEXT,
        situacao TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        velocidade_leve INTEGER,
        velocidade_pesado INTEGER,
        ingested_at TEXT NOT NULL
      );
    ''');

    // 3. Tabela individual Cadastro Nacional Aberto (DNIT / DERs / Inmetro / Municípios)
    db.execute('''
      CREATE TABLE IF NOT EXISTS source_nacional_aberto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo_externo TEXT,
        tipo_registro TEXT,
        uf TEXT,
        municipio TEXT,
        rodovia TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        velocidade INTEGER,
        sentido TEXT,
        situacao TEXT,
        fonte TEXT,
        ingested_at TEXT NOT NULL
      );
    ''');

    // 4. Tabela individual OpenStreetMap Comunitário
    db.execute('''
      CREATE TABLE IF NOT EXISTS source_osm_comunitario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        osm_id INTEGER,
        tipo TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        maxspeed INTEGER,
        direction INTEGER,
        road_name TEXT,
        operator TEXT,
        ingested_at TEXT NOT NULL
      );
    ''');

    // 5. Tabela de Sumário e Rastreabilidade das Fontes
    db.execute('''
      CREATE TABLE IF NOT EXISTS source_summary (
        source_name TEXT PRIMARY KEY,
        fetched_at TEXT NOT NULL,
        record_count INTEGER NOT NULL,
        status TEXT NOT NULL
      );
    ''');

    // 6. Inicializa o esquema de POIs padrão e índice espacial R*Tree do Sentinela
    final dbManager = DatabaseManager(db);
    dbManager.initializeSchema();
  }

  /// Ingestão e persistência na tabela `source_antt_pedagios`, retornando lista de [PoiPoint].
  List<PoiPoint> ingestAnttPedagios(Database db, List<dynamic> records) {
    if (records.isEmpty) return [];

    final stmt = db.prepare('''
      INSERT INTO source_antt_pedagios (
        concessionaria, praca_de_pedagio, rodovia, uf, km_m, municipio,
        tipo_de_pista, sentido, situacao, latitude, longitude,
        tarifa_automovel, tarifa_comercial, ingested_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    final now = DateTime.now().toUtc().toIso8601String();
    final List<PoiPoint> points = [];

    db.execute('BEGIN TRANSACTION;');
    try {
      int sequenceId = 100000;
      for (final raw in records) {
        if (raw is! Map) continue;
        final map = raw as Map<String, dynamic>;

        final latStr = (map['latitude']?.toString() ?? '')
            .replaceAll(',', '.')
            .trim();
        final lonStr = (map['longitude']?.toString() ?? '')
            .replaceAll(',', '.')
            .trim();
        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null || lat == 0.0 || lon == 0.0) continue;

        final concessionaria = map['concessionaria']?.toString() ?? '';
        final praca =
            map['praca_de_pedagio']?.toString() ??
            map['praca']?.toString() ??
            'Praça de Pedágio';
        final rodovia = map['rodovia']?.toString() ?? '';
        final uf = map['uf']?.toString() ?? '';
        final km = map['km_m']?.toString() ?? '';
        final municipio = map['municipio']?.toString() ?? '';
        final tipoPista = map['tipo_de_pista']?.toString() ?? '';
        final sentido = map['sentido']?.toString() ?? '';
        final situacao = map['situacao']?.toString() ?? 'Ativo';

        final tarifaAutoStr = (map['tarifa_automovel']?.toString() ?? '')
            .replaceAll(',', '.');
        final tarifaAuto = double.tryParse(tarifaAutoStr);
        final tarifaComStr = (map['tarifa_comercial']?.toString() ?? '')
            .replaceAll(',', '.');
        final tarifaCom = double.tryParse(tarifaComStr);

        stmt.execute([
          concessionaria,
          praca,
          rodovia,
          uf,
          km,
          municipio,
          tipoPista,
          sentido,
          situacao,
          lat,
          lon,
          tarifaAuto,
          tarifaCom,
          now,
        ]);

        final isFreeFlow =
            praca.toLowerCase().contains('free flow') ||
            praca.toLowerCase().contains('portico') ||
            tipoPista.toLowerCase().contains('free flow');

        final roadDisplay = rodovia.isNotEmpty
            ? (km.isNotEmpty ? '$rodovia km $km ($praca)' : '$rodovia - $praca')
            : praca;

        sequenceId++;
        points.add(
          PoiPoint(
            id: sequenceId,
            type: isFreeFlow ? PoiType.freeFlowToll : PoiType.tollBooth,
            latitude: lat,
            longitude: lon,
            speedLimit: isFreeFlow ? 100 : 40,
            roadName: roadDisplay,
            tollFeeCar: tarifaAuto,
            operator: concessionaria,
            city: municipio,
            state: uf,
            source: 'ANTT - Concessões Federais',
          ),
        );
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      stmt.close();
    }

    return points;
  }

  /// Ingestão e persistência na tabela `source_antt_radares`, retornando lista de [PoiPoint].
  List<PoiPoint> ingestAnttRadares(Database db, List<dynamic> records) {
    if (records.isEmpty) return [];

    final stmt = db.prepare('''
      INSERT INTO source_antt_radares (
        concessionaria, tipo_de_radar, rodovia, uf, km_m, municipio,
        tipo_de_pista, sentido, situacao, latitude, longitude,
        velocidade_leve, velocidade_pesado, ingested_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    final now = DateTime.now().toUtc().toIso8601String();
    final List<PoiPoint> points = [];

    db.execute('BEGIN TRANSACTION;');
    try {
      int sequenceId = 200000;
      for (final raw in records) {
        if (raw is! Map) continue;
        final map = raw as Map<String, dynamic>;

        final latStr = (map['latitude']?.toString() ?? '')
            .replaceAll(',', '.')
            .trim();
        final lonStr = (map['longitude']?.toString() ?? '')
            .replaceAll(',', '.')
            .trim();
        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null || lat == 0.0 || lon == 0.0) continue;

        final concessionaria = map['concessionaria']?.toString() ?? '';
        final tipoRadar = map['tipo_de_radar']?.toString() ?? 'Controlador';
        final rodovia = map['rodovia']?.toString() ?? '';
        final uf = map['uf']?.toString() ?? '';
        final km = map['km_m']?.toString() ?? '';
        final municipio = map['municipio']?.toString() ?? '';
        final tipoPista = map['tipo_de_pista']?.toString() ?? '';
        final sentido = map['sentido']?.toString() ?? '';
        final situacao = map['situacao']?.toString() ?? 'Ativo';

        final velLeveStr = map['velocidade_leve']?.toString() ?? '';
        final velLeve = int.tryParse(
          velLeveStr.replaceAll(RegExp(r'[^0-9]'), ''),
        );

        final velPesadoStr = map['velocidade_pesado']?.toString() ?? '';
        final velPesado = int.tryParse(
          velPesadoStr.replaceAll(RegExp(r'[^0-9]'), ''),
        );

        stmt.execute([
          concessionaria,
          tipoRadar,
          rodovia,
          uf,
          km,
          municipio,
          tipoPista,
          sentido,
          situacao,
          lat,
          lon,
          velLeve,
          velPesado,
          now,
        ]);

        final isSemaforo =
            tipoRadar.toLowerCase().contains('semaforo') ||
            tipoRadar.toLowerCase().contains('semáforo') ||
            tipoRadar.toLowerCase().contains('vermelho');

        final poiType = isSemaforo
            ? (velLeve != null
                  ? PoiType.trafficLightRadar
                  : PoiType.redLightCamera)
            : PoiType.fixedRadar;

        final roadDisplay = rodovia.isNotEmpty
            ? (km.isNotEmpty ? '$rodovia km $km' : rodovia)
            : 'Rodovia Federal';

        sequenceId++;
        points.add(
          PoiPoint(
            id: sequenceId,
            type: poiType,
            latitude: lat,
            longitude: lon,
            speedLimit: velLeve,
            roadName: roadDisplay,
            operator: concessionaria,
            city: municipio,
            state: uf,
            source: 'ANTT - Fiscalização Eletrônica',
          ),
        );
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      stmt.close();
    }

    return points;
  }

  /// Ingestão e persistência na tabela `source_nacional_aberto`, retornando lista de [PoiPoint].
  List<PoiPoint> ingestCadastroNacional(Database db, List<dynamic> records) {
    if (records.isEmpty) return [];

    final stmt = db.prepare('''
      INSERT INTO source_nacional_aberto (
        codigo_externo, tipo_registro, uf, municipio, rodovia,
        latitude, longitude, velocidade, sentido, situacao,
        fonte, ingested_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    final now = DateTime.now().toUtc().toIso8601String();
    final List<PoiPoint> points = [];

    db.execute('BEGIN TRANSACTION;');
    try {
      int sequenceId = 300000;
      for (final raw in records) {
        if (raw is! Map) continue;
        final map = raw as Map<String, dynamic>;

        final latStr = (map['latitude']?.toString() ?? '')
            .replaceAll(',', '.')
            .trim();
        final lonStr = (map['longitude']?.toString() ?? '')
            .replaceAll(',', '.')
            .trim();
        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null || lat == 0.0 || lon == 0.0) continue;

        final codigo = map['id']?.toString() ?? map['codigo']?.toString() ?? '';
        final tipo =
            map['tipo_radar']?.toString() ??
            map['tipo']?.toString() ??
            map['modalidade']?.toString() ??
            'Radar';
        final uf = map['uf']?.toString() ?? '';
        final municipio = map['municipio']?.toString() ?? '';
        final rodovia =
            map['via']?.toString() ?? map['rodovia']?.toString() ?? '';
        final situacao = map['situacao']?.toString() ?? 'ativo';

        final velStr =
            map['velocidade']?.toString() ??
            map['velocidade_regulamentada']?.toString() ??
            '';
        final vel = int.tryParse(velStr.replaceAll(RegExp(r'[^0-9]'), ''));

        final sentido = map['sentido']?.toString() ?? '';
        final fonteNome = map['fonte']?.toString() ?? 'Dados Abertos Nacionais';

        stmt.execute([
          codigo,
          tipo,
          uf,
          municipio,
          rodovia,
          lat,
          lon,
          vel,
          sentido,
          situacao,
          fonteNome,
          now,
        ]);

        final lowerTipo = tipo.toLowerCase();
        final PoiType poiType;
        if (lowerTipo.contains('semaforo') ||
            lowerTipo.contains('semáforo') ||
            lowerTipo.contains('vermelho')) {
          poiType = (vel != null && vel > 0)
              ? PoiType.trafficLightRadar
              : PoiType.redLightCamera;
        } else if (lowerTipo.contains('movel') ||
            lowerTipo.contains('móvel') ||
            lowerTipo.contains('portatil')) {
          poiType = PoiType.mobileRadar;
        } else if (lowerTipo.contains('lombada') ||
            lowerTipo.contains('eletronica')) {
          poiType = PoiType.electronicSpeedBump;
        } else if (lowerTipo.contains('pedagio') ||
            lowerTipo.contains('pedágio')) {
          poiType = PoiType.tollBooth;
        } else if (lowerTipo.contains('policia') ||
            lowerTipo.contains('polícia')) {
          poiType = PoiType.highwayPatrol;
        } else {
          poiType = PoiType.fixedRadar;
        }

        sequenceId++;
        points.add(
          PoiPoint(
            id: sequenceId,
            type: poiType,
            latitude: lat,
            longitude: lon,
            speedLimit: vel,
            roadName: rodovia.isNotEmpty ? rodovia : 'Via Pública',
            city: municipio,
            state: uf,
            source: fonteNome,
          ),
        );
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      stmt.close();
    }

    return points;
  }

  /// Ingestão e persistência na tabela `source_osm_comunitario`.
  List<PoiPoint> ingestOsmComunitario(Database db, List<PoiPoint> points) {
    if (points.isEmpty) return [];

    final stmt = db.prepare('''
      INSERT INTO source_osm_comunitario (
        osm_id, tipo, latitude, longitude, maxspeed,
        direction, road_name, operator, ingested_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    final now = DateTime.now().toUtc().toIso8601String();

    db.execute('BEGIN TRANSACTION;');
    try {
      for (final p in points) {
        stmt.execute([
          p.id,
          p.type.name,
          p.latitude,
          p.longitude,
          p.speedLimit,
          p.direction,
          p.roadName,
          p.operator,
          now,
        ]);
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      stmt.close();
    }

    return points;
  }

  /// Deduplica a lista consolidada de POIs garantindo fusão inteligente em raio < [distanceThresholdMeters].
  /// Utiliza indexação espacial por grade (Spatial Hashing O(N)) para processar mais de 70.000 pontos em milissegundos.
  List<PoiPoint> deduplicatePois(
    List<PoiPoint> pois, {
    double distanceThresholdMeters = 35.0,
  }) {
    final List<PoiPoint> retained = [];
    // Grade de ~550 metros para busca de vizinhança imediata
    const double gridStep = 0.005;
    final Map<int, List<int>> spatialGrid = {};

    int getCellKey(int latBin, int lonBin) {
      return ((latBin & 0xFFFF) << 16) | (lonBin & 0xFFFF);
    }

    for (final candidate in pois) {
      final latBin = (candidate.latitude / gridStep).floor();
      final lonBin = (candidate.longitude / gridStep).floor();

      int duplicateIndex = -1;

      // Percorre os 9 blocos adjacentes (bloco central + 8 vizinhos)
      outerLoop:
      for (int dLat = -1; dLat <= 1; dLat++) {
        for (int dLon = -1; dLon <= 1; dLon++) {
          final cellKey = getCellKey(latBin + dLat, lonBin + dLon);
          final candidatesInCell = spatialGrid[cellKey];
          if (candidatesInCell == null) continue;

          for (final idx in candidatesInCell) {
            final existing = retained[idx];

            final distance = haversineDistance(
              candidate.latitude,
              candidate.longitude,
              existing.latitude,
              existing.longitude,
            );

            if (distance <= distanceThresholdMeters) {
              if (!_areTypesCompatible(candidate.type, existing.type)) {
                continue;
              }

              if (candidate.direction != null && existing.direction != null) {
                final diff = bearingDifference(
                  candidate.direction!,
                  existing.direction!,
                );
                if (diff > 60.0) {
                  continue;
                }
              }

              duplicateIndex = idx;
              break outerLoop;
            }
          }
        }
      }

      if (duplicateIndex >= 0) {
        // Fusão enriquecida: mescla informações preservando o registro mais detalhado
        final existing = retained[duplicateIndex];
        final merged = _mergePoiPoints(existing, candidate);
        retained[duplicateIndex] = merged;
      } else {
        final newIndex = retained.length;
        retained.add(candidate);
        final cellKey = getCellKey(latBin, lonBin);
        spatialGrid.putIfAbsent(cellKey, () => []).add(newIndex);
      }
    }

    final List<PoiPoint> reindexed = [];
    for (int i = 0; i < retained.length; i++) {
      reindexed.add(retained[i].copyWith(id: i + 1));
    }
    return reindexed;
  }

  /// Salva os POIs consolidados nas tabelas `pois` e `pois_index` com R*Tree e atualiza sumários.
  void saveConsolidatedPois(
    Database db,
    List<PoiPoint> pois, {
    Map<String, int>? sourceSummaries,
    DateTime? lastUpdated,
  }) {
    final dbManager = DatabaseManager(db);
    dbManager.initializeSchema();

    // Limpa tabelas consolidadas anteriores
    db.execute('DELETE FROM pois;');
    db.execute('DELETE FROM pois_index;');

    // Insere batch na tabela de produção
    dbManager.insertPoisBatch(pois);

    final updateTime = lastUpdated ?? DateTime.now().toUtc();
    dbManager.setMetadata('total_count', pois.length.toString());
    dbManager.setMetadata('last_updated', updateTime.toIso8601String());
    dbManager.setMetadata(
      'source',
      'Multi-Source Brasil (ANTT, DNIT, OpenStreetMap)',
    );
    dbManager.setMetadata('schema_version', '2');

    // Atualiza tabela source_summary
    if (sourceSummaries != null) {
      final summaryStmt = db.prepare('''
        INSERT OR REPLACE INTO source_summary (source_name, fetched_at, record_count, status)
        VALUES (?, ?, ?, ?);
      ''');

      for (final entry in sourceSummaries.entries) {
        summaryStmt.execute([
          entry.key,
          updateTime.toIso8601String(),
          entry.value,
          'SUCCESS',
        ]);
      }
      summaryStmt.close();
    }
  }

  bool _areTypesCompatible(PoiType a, PoiType b) {
    if (a == b) return true;
    final isRadarA =
        a == PoiType.fixedRadar ||
        a == PoiType.trafficLightRadar ||
        a == PoiType.redLightCamera;
    final isRadarB =
        b == PoiType.fixedRadar ||
        b == PoiType.trafficLightRadar ||
        b == PoiType.redLightCamera;
    if (isRadarA && isRadarB) return true;

    final isTollA = a == PoiType.tollBooth || a == PoiType.freeFlowToll;
    final isTollB = b == PoiType.tollBooth || b == PoiType.freeFlowToll;
    if (isTollA && isTollB) return true;

    final isBumpA =
        a == PoiType.physicalSpeedBump || a == PoiType.electronicSpeedBump;
    final isBumpB =
        b == PoiType.physicalSpeedBump || b == PoiType.electronicSpeedBump;
    if (isBumpA && isBumpB) return true;

    return false;
  }

  PoiPoint _mergePoiPoints(PoiPoint a, PoiPoint b) {
    final speed = a.speedLimit ?? b.speedLimit;
    final direction = a.direction ?? b.direction;
    final road = a.roadName.isNotEmpty ? a.roadName : b.roadName;
    final operator = (a.operator != null && a.operator!.isNotEmpty)
        ? a.operator
        : b.operator;
    final city = (a.city != null && a.city!.isNotEmpty) ? a.city : b.city;
    final state = (a.state != null && a.state!.isNotEmpty) ? a.state : b.state;
    final toll = a.tollFeeCar ?? b.tollFeeCar;

    final chosenType =
        (a.speedLimit != null && a.type == PoiType.trafficLightRadar)
        ? a.type
        : ((b.speedLimit != null && b.type == PoiType.trafficLightRadar)
              ? b.type
              : a.type);

    final src = (a.source != null && b.source != null && a.source != b.source)
        ? '${a.source} + ${b.source}'
        : (a.source ?? b.source);

    return PoiPoint(
      id: math.min(a.id, b.id),
      type: chosenType,
      latitude: a.latitude,
      longitude: a.longitude,
      speedLimit: speed,
      direction: direction,
      toleranceAngle: a.toleranceAngle,
      roadName: road,
      tollFeeCar: toll,
      operator: operator,
      city: city,
      state: state,
      source: src,
    );
  }
}
