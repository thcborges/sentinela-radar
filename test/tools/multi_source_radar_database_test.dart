import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/domain/sync/multi_source_radar_builder.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sentinela_multi_source_test_');
    dbPath = '${tempDir.path}/test_multisource.db';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('MultiSourceRadarBuilder - Pipeline de Fontes Múltiplas e Banco SQLite', () {
    test('deve inicializar tabelas individuais por fonte e tabela consolidada com indice espacial', () {
      final builder = MultiSourceRadarBuilder();
      final db = sqlite3.open(dbPath);
      builder.initializeMultiSourceSchema(db);

      // Verifica tabelas individuais por fonte
      final tables = db.select("SELECT name FROM sqlite_master WHERE type='table';").map((r) => r['name'] as String).toSet();
      expect(tables.contains('source_antt_pedagios'), isTrue);
      expect(tables.contains('source_antt_radares'), isTrue);
      expect(tables.contains('source_prf_radares'), isTrue);
      expect(tables.contains('source_dnit_pncv'), isTrue);
      expect(tables.contains('source_nacional_aberto'), isTrue);
      expect(tables.contains('source_osm_comunitario'), isTrue);
      expect(tables.contains('source_summary'), isTrue);
      expect(tables.contains('pois'), isTrue);
      expect(tables.contains('pois_index'), isTrue);
      expect(tables.contains('db_metadata'), isTrue);

      db.close();
    });

    test('deve inserir dados da ANTT Pedagios na tabela source_antt_pedagios e mapear para POIs', () {
      final builder = MultiSourceRadarBuilder();
      final db = sqlite3.open(dbPath);
      builder.initializeMultiSourceSchema(db);

      final samplePedagios = [
        {
          'concessionaria': 'AUTOPISTA FLUMINENSE',
          'praca_de_pedagio': 'Conselheiro Josino',
          'rodovia': 'BR-101',
          'uf': 'RJ',
          'km_m': '40.5',
          'municipio': 'Campos dos Goytacazes',
          'sentido': 'Crescente/Decrescente',
          'latitude': '-21.552594',
          'longitude': '-41.331597',
        },
        {
          'concessionaria': 'ECOVIAS DO CERRADO',
          'praca_de_pedagio': 'Uberlândia',
          'rodovia': 'BR-365',
          'uf': 'MG',
          'km_m': '641',
          'municipio': 'Uberlândia',
          'sentido': 'Bidirecional',
          'latitude': '-18.892300',
          'longitude': '-48.351200',
        }
      ];

      final pois = builder.ingestAnttPedagios(db, samplePedagios);
      expect(pois.length, equals(2));
      expect(pois.first.type, equals(PoiType.tollBooth));
      expect(pois.first.roadName, contains('BR-101'));
      expect(pois.first.operator, equals('AUTOPISTA FLUMINENSE'));

      final rows = db.select('SELECT COUNT(*) AS count FROM source_antt_pedagios;');
      expect(rows.first['count'], equals(2));

      db.close();
    });

    test('deve inserir dados da ANTT Radares na tabela source_antt_radares e mapear para POIs', () {
      final builder = MultiSourceRadarBuilder();
      final db = sqlite3.open(dbPath);
      builder.initializeMultiSourceSchema(db);

      final sampleRadares = [
        {
          'concessionaria': 'AUTOPISTA FLUMINENSE',
          'tipo_de_radar': 'Controlador',
          'rodovia': 'BR-101',
          'uf': 'RJ',
          'km_m': '58,805',
          'municipio': 'Campos dos Goytacazes',
          'sentido': 'Decrescente',
          'latitude': '-21,713412',
          'longitude': '-41,308561',
          'velocidade_leve': '60',
          'velocidade_pesado': '60',
        }
      ];

      final pois = builder.ingestAnttRadares(db, sampleRadares);
      expect(pois.length, equals(1));
      expect(pois.first.type, equals(PoiType.fixedRadar));
      expect(pois.first.speedLimit, equals(60));
      expect(pois.first.latitude, closeTo(-21.713412, 0.00001));
      expect(pois.first.longitude, closeTo(-41.308561, 0.00001));

      final rows = db.select('SELECT COUNT(*) AS count FROM source_antt_radares;');
      expect(rows.first['count'], equals(1));

      db.close();
    });

    test('deve inserir dados da PRF na tabela source_prf_radares e mapear para POIs', () {
      final builder = MultiSourceRadarBuilder();
      final db = sqlite3.open(dbPath);
      builder.initializeMultiSourceSchema(db);

      final samplePrf = [
        {
          'IDENTIFICADOR': 'PRF-001',
          'CONCESSIONÁRIA': 'NOVADUTRA',
          'BR': '116',
          'UF': 'RJ',
          'LOCAL': '165.5',
          'MUNICÍPIO': 'São João de Meriti',
          'SENTIDO': 'Crescente',
          'FAIXAS': '3',
          'TIPO EQUIPAMENTO': 'CONTROLADOR',
          'LATITUDE': -22.8021,
          'LONGITUDE': -43.3712,
          'VELOCIDADE LEVE': '80',
          'VELOCIDADE PESADO': '80',
          'ESTADO': 'ATIVO',
        },
        {
          'IDENTIFICADOR': 'PRF-002',
          'CONCESSIONÁRIA': '',
          'BR': 'BR-101',
          'UF': 'SC',
          'LOCAL': '200',
          'MUNICÍPIO': 'São José',
          'SENTIDO': 'Decrescente',
          'FAIXAS': '2',
          'TIPO EQUIPAMENTO': 'REDUTOR',
          'LATITUDE': -27.6012,
          'LONGITUDE': -48.6234,
          'VELOCIDADE LEVE': '60',
          'VELOCIDADE PESADO': '60',
          'ESTADO': 'ATIVO',
        }
      ];

      final pois = builder.ingestPrfRadares(db, samplePrf);
      expect(pois.length, equals(2));
      expect(pois[0].type, equals(PoiType.fixedRadar));
      expect(pois[0].speedLimit, equals(80));
      expect(pois[0].roadName, equals('BR-116'));
      expect(pois[1].type, equals(PoiType.electronicSpeedBump));
      expect(pois[1].speedLimit, equals(60));

      final rows = db.select('SELECT COUNT(*) AS count FROM source_prf_radares;');
      expect(rows.first['count'], equals(2));

      db.close();
    });

    test('deve inserir dados do DNIT PNCV na tabela source_dnit_pncv e mapear para POIs', () {
      final builder = MultiSourceRadarBuilder();
      final db = sqlite3.open(dbPath);
      builder.initializeMultiSourceSchema(db);

      final sampleDnit = [
        {
          'codigo': 'DNIT-5421',
          'uf': 'MG',
          'rodovia': 'BR-381',
          'km': '480.2',
          'municipio': 'Betim',
          'faixas': '2',
          'tipo': 'RAD',
          'marca_modelo': 'Fotosensores',
          'latitude': -19.9823,
          'longitude': -44.2012,
          'velocidade': '80',
          'situacao': 'Ativo',
        },
        {
          'codigo': 'DNIT-5422',
          'uf': 'RS',
          'rodovia': 'BR-290',
          'km': '112.0',
          'municipio': 'Eldorado do Sul',
          'faixas': '1',
          'tipo': 'REV',
          'marca_modelo': 'Perkons',
          'latitude': -30.0123,
          'longitude': -51.3412,
          'velocidade': '50',
          'situacao': 'Ativo',
        }
      ];

      final pois = builder.ingestDnitPncv(db, sampleDnit);
      expect(pois.length, equals(2));
      expect(pois[0].type, equals(PoiType.fixedRadar));
      expect(pois[0].speedLimit, equals(80));
      expect(pois[0].state, equals('MG'));
      expect(pois[1].type, equals(PoiType.electronicSpeedBump));
      expect(pois[1].speedLimit, equals(50));
      expect(pois[1].state, equals('RS'));

      final rows = db.select('SELECT COUNT(*) AS count FROM source_dnit_pncv;');
      expect(rows.first['count'], equals(2));

      db.close();
    });

    test('deve deduplicar pontos próximos (<35m) e priorizar informações mais completas na tabela consolidada', () {
      final builder = MultiSourceRadarBuilder();
      final db = sqlite3.open(dbPath);
      builder.initializeMultiSourceSchema(db);

      // Ponto 1: Sem velocidade da base comunitária
      const p1 = PoiPoint(
        id: 101,
        type: PoiType.fixedRadar,
        latitude: -22.906847,
        longitude: -43.172896,
        roadName: 'Aterro do Flamengo',
      );

      // Ponto 2: Mesmo local (<20m) da base oficial com limite de 80 km/h e órgão
      const p2 = PoiPoint(
        id: 102,
        type: PoiType.fixedRadar,
        latitude: -22.906900,
        longitude: -43.172920,
        speedLimit: 80,
        roadName: 'Aterro do Flamengo - Pista Central',
        operator: 'CET-RIO',
        source: 'Oficial',
      );

      // Ponto 3: Ponto distante (São Paulo)
      const p3 = PoiPoint(
        id: 201,
        type: PoiType.trafficLightRadar,
        latitude: -23.550520,
        longitude: -46.633308,
        speedLimit: 50,
        roadName: 'Av. 23 de Maio',
      );

      final consolidated = builder.deduplicatePois([p1, p2, p3], distanceThresholdMeters: 35.0);
      expect(consolidated.length, equals(2));

      // Verifica se o ponto fundido preservou a velocidade e atributos mais ricos
      final aterroPoi = consolidated.firstWhere((p) => p.roadName.contains('Aterro'));
      expect(aterroPoi.speedLimit, equals(80));
      expect(aterroPoi.operator, equals('CET-RIO'));

      // Salva consolidados no banco
      builder.saveConsolidatedPois(db, consolidated, sourceSummaries: {
        'source_antt_pedagios': 0,
        'source_antt_radares': 1,
        'source_nacional_aberto': 1,
        'source_osm_comunitario': 1,
      });

      // Valida via DatabaseManager com índice R*Tree
      final dbManager = DatabaseManager(db);
      final results = dbManager.searchBoundingBox(
        minLat: -23.0,
        maxLat: -22.8,
        minLon: -43.3,
        maxLon: -43.0,
      );

      expect(results.length, equals(1));
      expect(results.first.roadName, contains('Aterro'));
      expect(results.first.speedLimit, equals(80));

      final metaCount = dbManager.getMetadata('total_count');
      expect(metaCount, equals('2'));

      db.close();
    });
  });
}
