import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/poi_model.dart';
import 'package:sentinela/core/network/connectivity_checker.dart';
import 'federal_open_data_parser.dart';
import 'poi_sync_parser.dart';
import 'sync_mirror_manager.dart';

/// Ciclo de vida e status da rotina de sincronização de dados abertos.
enum SyncStatus {
  idle,
  downloading,
  processing,
  saving,
  success,
  error,
}

/// Estado do progresso da sincronização consumível pela UI/Dashboard.
class SyncProgress extends Equatable {
  final SyncStatus status;
  final String message;
  final double progress; // 0.0 a 1.0
  final Map<String, int>? stats;

  const SyncProgress({
    required this.status,
    required this.message,
    this.progress = 0.0,
    this.stats,
  });

  @override
  List<Object?> get props => [status, message, progress, stats];
}

/// Serviço de sincronização e atualização sob demanda da base de POIs
/// com transação atômica em staging tables e rollback automático.
class PoiSyncService {
  final Database db;
  final http.Client _client;
  final String overpassUrl;
  final String? directReleaseUrl;
  final bool _ownsClient;
  final NetworkConnectivityChecker? _connectivityChecker;
  final SyncMirrorManager? _mirrorManager;

  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();

  PoiSyncService(
    this.db, {
    http.Client? httpClient,
    this.overpassUrl = 'https://overpass-api.de/api/interpreter',
    this.directReleaseUrl,
    NetworkConnectivityChecker? connectivityChecker,
    SyncMirrorManager? mirrorManager,
  })  : _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _connectivityChecker = connectivityChecker,
        _mirrorManager = mirrorManager;

  /// Stream reativo para acompanhamento na tela de Configurações em tempo real.
  Stream<SyncProgress> get progressStream => _progressController.stream;

  /// Fecha recursos e canais de stream.
  void dispose() {
    _progressController.close();
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Dispara a sincronização in-app sob demanda.
  Future<bool> startInAppUpdate({bool requireWifi = false}) =>
      syncFromRemote(requireWifi: requireWifi);

  /// Dispara a sincronização conectando ao endpoint de release direta ou Overpass API via rede.
  Future<bool> syncFromRemote({
    bool requireWifi = false,
    String? customQuery,
  }) async {
    if (requireWifi && _connectivityChecker != null) {
      final isWifi = await _connectivityChecker.isWifiConnected();
      if (!isWifi) {
        _progressController.add(const SyncProgress(
          status: SyncStatus.error,
          message: 'Sincronização configurada para Wi-Fi. Conecte-se a uma rede Wi-Fi para atualizar.',
        ));
        return false;
      }
    }

    // 1. Tenta download de release pré-compilada rápida se configurada
    if (directReleaseUrl != null) {
      try {
        _progressController.add(const SyncProgress(
          status: SyncStatus.downloading,
          message: 'Baixando release direta da base de POIs...',
          progress: 0.2,
        ));
        final response = await _client.get(
          Uri.parse(directReleaseUrl!),
          headers: {'User-Agent': 'Sentinela/1.0 (Mobile Direct Sync)'},
        ).timeout(const Duration(minutes: 2));

        if (response.statusCode == 200) {
          return await _processAndCommit(response.body);
        }
      } catch (_) {
        // Fallback automático para consulta Overpass caso a release direta falhe
      }
    }

    _progressController.add(const SyncProgress(
      status: SyncStatus.downloading,
      message: 'Conectando e baixando dados abertos do Brasil...',
      progress: 0.1,
    ));

    const defaultQuery = '''
    [out:json][timeout:180];
    (
      node["highway"="speed_camera"](-33.75,-73.99,5.27,-34.79);
      node["enforcement"="maxspeed"](-33.75,-73.99,5.27,-34.79);
      node["enforcement"="red_light"](-33.75,-73.99,5.27,-34.79);
      node["camera:traffic_signals"="yes"](-33.75,-73.99,5.27,-34.79);
      node["traffic_calming"~"bump|table|hump"](-33.75,-73.99,5.27,-34.79);
      node["barrier"="toll_booth"](-33.75,-73.99,5.27,-34.79);
      node["highway"="toll_gantry"](-33.75,-73.99,5.27,-34.79);
    );
    out body;
    ''';

    try {
      final http.Response response;
      if (_mirrorManager != null) {
        response = await _mirrorManager.postQueryWithFailover(
          query: customQuery ?? defaultQuery,
          timeout: const Duration(minutes: 5),
        );
      } else {
        response = await _client.post(
          Uri.parse(overpassUrl),
          body: {'data': customQuery ?? defaultQuery},
          headers: {'User-Agent': 'Sentinela/1.0 (Mobile Sync)'},
        ).timeout(const Duration(minutes: 5));
      }

      if (response.statusCode != 200) {
        _progressController.add(SyncProgress(
          status: SyncStatus.error,
          message: 'Falha HTTP ${response.statusCode} ao consultar dados abertos.',
        ));
        return false;
      }

      return await _processAndCommit(response.body);
    } catch (e) {
      _progressController.add(SyncProgress(
        status: SyncStatus.error,
        message: 'Erro durante o download da base: $e',
      ));
      return false;
    }
  }

  /// Processa diretamente uma carga JSON (para testes herméticos ou seeds locais).
  Future<bool> syncFromJson(String jsonPayload) async {
    return _processAndCommit(jsonPayload);
  }

  /// Ingestão e sincronização direta a partir de conjuntos de dados governamentais
  /// abertos (DNIT PNCV e ANTT Concessões/Free Flow).
  Future<bool> syncFromFederalData({
    String? dnitPayload,
    String? anttPayload,
    bool isCsv = false,
  }) async {
    try {
      _progressController.add(const SyncProgress(
        status: SyncStatus.processing,
        message: 'Processando bases federais (DNIT / ANTT)...',
        progress: 0.2,
      ));

      final allPois = <PoiPoint>[];
      if (dnitPayload != null && dnitPayload.isNotEmpty) {
        final dnitPois = isCsv
            ? FederalOpenDataParser.parseDnitCsv(dnitPayload)
            : FederalOpenDataParser.parseDnitJson(dnitPayload);
        allPois.addAll(dnitPois);
      }

      if (anttPayload != null && anttPayload.isNotEmpty) {
        final anttPois = isCsv
            ? FederalOpenDataParser.parseAnttCsv(anttPayload)
            : FederalOpenDataParser.parseAnttJson(anttPayload);
        allPois.addAll(anttPois);
      }

      if (allPois.isEmpty) {
        _progressController.add(const SyncProgress(
          status: SyncStatus.error,
          message: 'Nenhum registro válido encontrado nas bases federais informadas.',
        ));
        return false;
      }

      final deduplicated = PoiSyncParser.deduplicatePois(allPois);
      return await _commitPois(deduplicated);
    } catch (e) {
      _progressController.add(SyncProgress(
        status: SyncStatus.error,
        message: 'Falha durante o processamento de dados federais: $e',
      ));
      return false;
    }
  }

  /// Realiza o parsing, deduplicação e swap atômico das tabelas no SQLite.
  Future<bool> _processAndCommit(String payload) async {
    try {
      _progressController.add(const SyncProgress(
        status: SyncStatus.processing,
        message: 'Decodificando e deduplicando pontos...',
        progress: 0.4,
      ));

      final rawPois = PoiSyncParser.parseJsonPayload(payload);
      final dedupPois = PoiSyncParser.deduplicatePois(rawPois);

      return await _commitPois(dedupPois);
    } catch (e) {
      _progressController.add(SyncProgress(
        status: SyncStatus.error,
        message: 'Falha durante o processamento ou gravação atômica: $e',
      ));
      return false;
    }
  }

  Future<bool> _commitPois(List<PoiPoint> dedupPois) async {
    try {
      _progressController.add(SyncProgress(
        status: SyncStatus.saving,
        message: 'Gravando ${dedupPois.length} pontos com swap atômico...',
        progress: 0.7,
      ));

      final stats = <String, int>{
        'radares': 0,
        'semaforos': 0,
        'lombadas': 0,
        'pedagios': 0,
        'policia': 0,
      };

      // Executa toda a substituição dentro de uma única transação atômica
      db.execute('BEGIN TRANSACTION;');
      try {
        // 1. Limpa e cria as tabelas de staging
        db.execute('DROP TABLE IF EXISTS pois_staging;');
        db.execute('DROP TABLE IF EXISTS pois_index_staging;');

        db.execute('''
          CREATE TABLE pois_staging (
              id INTEGER PRIMARY KEY,
              type INTEGER NOT NULL,
              speed_limit INTEGER,
              direction INTEGER,
              tolerance_angle REAL DEFAULT 35.0,
              road_name TEXT,
              toll_fee_car REAL,
              operator TEXT,
              city TEXT,
              state TEXT,
              source TEXT
          );
        ''');

        db.execute('''
          CREATE VIRTUAL TABLE pois_index_staging USING rtree(
              id,
              min_lat, max_lat,
              min_lon, max_lon
          );
        ''');

        // 2. Inserção em lote na staging
        final insertPoiStmt = db.prepare('''
          INSERT OR REPLACE INTO pois_staging (
            id, type, speed_limit, direction, tolerance_angle, road_name, toll_fee_car, operator, city, state, source
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''');

        final insertIndexStmt = db.prepare('''
          INSERT OR REPLACE INTO pois_index_staging (id, min_lat, max_lat, min_lon, max_lon)
          VALUES (?, ?, ?, ?, ?);
        ''');

        for (final poi in dedupPois) {
          insertPoiStmt.execute([
            poi.id,
            poi.type.code,
            poi.speedLimit,
            poi.direction,
            poi.toleranceAngle,
            poi.roadName,
            poi.tollFeeCar,
            poi.operator,
            poi.city,
            poi.state,
            poi.source,
          ]);

          insertIndexStmt.execute([
            poi.id,
            poi.latitude,
            poi.latitude,
            poi.longitude,
            poi.longitude,
          ]);

          // Computa estatísticas da nova base
          if (poi.type == PoiType.fixedRadar || poi.type == PoiType.mobileRadar) {
            stats['radares'] = (stats['radares'] ?? 0) + 1;
          } else if (poi.type.isRedLightEnforcement) {
            stats['semaforos'] = (stats['semaforos'] ?? 0) + 1;
          } else if (poi.type.isSpeedBump) {
            stats['lombadas'] = (stats['lombadas'] ?? 0) + 1;
          } else if (poi.type.isToll) {
            stats['pedagios'] = (stats['pedagios'] ?? 0) + 1;
          } else if (poi.type == PoiType.highwayPatrol) {
            stats['policia'] = (stats['policia'] ?? 0) + 1;
          }
        }

        insertPoiStmt.close();
        insertIndexStmt.close();

        // 3. Swap atômico de tabelas sem downtime
        db.execute('DROP TABLE IF EXISTS pois;');
        db.execute('DROP TABLE IF EXISTS pois_index;');
        db.execute('ALTER TABLE pois_staging RENAME TO pois;');
        db.execute('ALTER TABLE pois_index_staging RENAME TO pois_index;');

        // 4. Atualiza metadados
        db.execute('''
          INSERT OR REPLACE INTO db_metadata (key, value)
          VALUES ('last_updated', ?),
                 ('total_count', ?);
        ''', [
          DateTime.now().toIso8601String(),
          dedupPois.length.toString(),
        ]);

        db.execute('COMMIT;');
      } catch (e) {
        db.execute('ROLLBACK;');
        rethrow;
      }

      _progressController.add(SyncProgress(
        status: SyncStatus.success,
        message: 'Base atualizada com sucesso (${dedupPois.length} pontos).',
        progress: 1.0,
        stats: stats,
      ));

      return true;
    } catch (e) {
      _progressController.add(SyncProgress(
        status: SyncStatus.error,
        message: 'Falha durante o processamento ou gravação atômica: $e',
      ));
      return false;
    }
  }
}
