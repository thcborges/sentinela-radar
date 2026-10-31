import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/network/connectivity_checker.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/data/sync/sync_mirror_manager.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockConnectivityChecker extends Mock implements NetworkConnectivityChecker {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://overpass-api.de/api/interpreter'));
  });

  group('PoiSyncService with Atomic Staging Swap', () {
    late Database db;
    late DatabaseManager dbManager;
    late MockHttpClient mockClient;
    late PoiSyncService syncService;

    setUp(() {
      db = sqlite3.openInMemory();
      dbManager = DatabaseManager(db);
      dbManager.initializeSchema();
      mockClient = MockHttpClient();
      syncService = PoiSyncService(db, httpClient: mockClient);
    });

    tearDown(() {
      syncService.dispose();
      db.close();
    });

    const validOverpassJson = '''
    {
      "elements": [
        {
          "type": "node",
          "id": 1,
          "lat": -23.5505,
          "lon": -46.6333,
          "tags": {
            "highway": "speed_camera",
            "maxspeed": "60",
            "direction": "90"
          }
        },
        {
          "type": "node",
          "id": 2,
          "lat": -23.5600,
          "lon": -46.6400,
          "tags": {
            "traffic_calming": "bump"
          }
        }
      ]
    }
    ''';

    test('deve executar swap atômico com sucesso e atualizar pois e pois_index', () async {
      // 1. Popula base antiga inicial com 1 ponto
      dbManager.insertPoi(const PoiPoint(
        id: 999,
        type: PoiType.fixedRadar,
        latitude: 0,
        longitude: 0,
      ));
      expect(dbManager.getTotalCount(), equals(1));

      // 2. Mock da requisição HTTP Overpass
      when(() => mockClient.post(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(validOverpassJson, 200));

      final success = await syncService.syncFromRemote();

      expect(success, isTrue);
      // A base deve ter sido atualizada com os 2 novos pontos (swap atômico substituiu o antigo 999)
      expect(dbManager.getTotalCount(), equals(2));

      // Verifica se o índice espacial R*Tree está funcionando pós-swap
      final search = dbManager.searchBoundingBox(
        minLat: -23.6,
        maxLat: -23.5,
        minLon: -46.7,
        maxLon: -46.6,
      );
      expect(search.length, equals(2));

      // Verifica metadados de última atualização
      expect(dbManager.getMetadata('total_count'), equals('2'));
      expect(dbManager.getMetadata('last_updated'), isNotNull);
    });

    test('em caso de erro HTTP ou de rede, a base original deve permanecer 100% intacta (Rollback)', () async {
      // 1. Base ativa original
      dbManager.insertPoi(const PoiPoint(
        id: 42,
        type: PoiType.fixedRadar,
        latitude: -15.0,
        longitude: -47.0,
        roadName: 'Base Intacta',
      ));
      expect(dbManager.getTotalCount(), equals(1));

      // 2. Simula falha 504 Gateway Timeout
      when(() => mockClient.post(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response('Server Error', 504));

      final success = await syncService.syncFromRemote();

      expect(success, isFalse);
      // Base antiga continua intacta
      expect(dbManager.getTotalCount(), equals(1));
      final original = db.select('SELECT * FROM pois WHERE id = 42');
      expect(original.first['road_name'], equals('Base Intacta'));
    });

    test('syncFromJson deve permitir atualização direta sem chamada de rede (ex: testes ou backup local)', () async {
      final statuses = <SyncStatus>[];
      final subscription = syncService.progressStream.listen((progress) {
        statuses.add(progress.status);
      });

      final success = await syncService.syncFromJson(validOverpassJson);

      expect(success, isTrue);
      expect(dbManager.getTotalCount(), equals(2));

      // Aguarda o ciclo do event loop para entrega de todos os eventos da Stream
      await Future<void>.delayed(Duration.zero);
      expect(statuses, containsAll([SyncStatus.processing, SyncStatus.saving, SyncStatus.success]));

      await subscription.cancel();
    });

    test('SyncProgress deve suportar props do Equatable', () {
      const p1 = SyncProgress(status: SyncStatus.idle, message: 'Pronto');
      const p2 = SyncProgress(status: SyncStatus.idle, message: 'Pronto');
      expect(p1, equals(p2));
      expect(p1.props, equals(p2.props));
    });

    test('deve tratar exceção de rede lançada pelo cliente HTTP', () async {
      when(() => mockClient.post(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenThrow(http.ClientException('Conexão recusada'));

      final success = await syncService.syncFromRemote();
      expect(success, isFalse);
    });

    test('deve tratar JSON corrompido em syncFromJson retornando false e emitindo erro', () async {
      final success = await syncService.syncFromJson('{"corrompido:');
      expect(success, isFalse);
    });

    test('deve bloquear sincronização se requireWifi for true e dispositivo não estiver em Wi-Fi', () async {
      final mockConn = MockConnectivityChecker();
      when(() => mockConn.isWifiConnected()).thenAnswer((_) async => false);

      final wifiSyncService = PoiSyncService(
        db,
        httpClient: mockClient,
        connectivityChecker: mockConn,
      );

      final progressEvents = <SyncProgress>[];
      final sub = wifiSyncService.progressStream.listen(progressEvents.add);

      final success = await wifiSyncService.syncFromRemote(requireWifi: true);
      await Future<void>.delayed(Duration.zero);
      expect(success, isFalse);
      expect(progressEvents.any((p) => p.status == SyncStatus.error && p.message.contains('Wi-Fi')), isTrue);

      await sub.cancel();
      wifiSyncService.dispose();
    });

    test('deve permitir sincronização se requireWifi for true e dispositivo estiver em Wi-Fi', () async {
      final mockConn = MockConnectivityChecker();
      when(() => mockConn.isWifiConnected()).thenAnswer((_) async => true);
      when(() => mockClient.post(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(validOverpassJson, 200));

      final wifiSyncService = PoiSyncService(
        db,
        httpClient: mockClient,
        connectivityChecker: mockConn,
      );

      final success = await wifiSyncService.syncFromRemote(requireWifi: true);
      expect(success, isTrue);

      wifiSyncService.dispose();
    });

    test('construtor padrão sem httpClient deve criar e descartar client próprio com sucesso', () {
      final standalone = PoiSyncService(db);
      expect(standalone, isNotNull);
      standalone.dispose();
    });

    test('syncFromFederalData deve ingerir dados do DNIT e ANTT com swap atômico', () async {
      const dnitCsv = '''id,uf,rodovia,km,municipio,tipo_equipamento,velocidade_regulamentada,latitude,longitude,sentido
301,SP,BR-116,200.0,São Paulo,Radar Fixo,80,-23.5505,-46.6333,Ambos
''';
      const anttCsv = '''id,concessionaria,rodovia,km,municipio,uf,tipo_praca,tarifa_carro,latitude,longitude
302,CCR,BR-116,210.0,Guarulhos,SP,Free Flow,4.50,-23.4600,-46.5300
''';

      final success = await syncService.syncFromFederalData(
        dnitPayload: dnitCsv,
        anttPayload: anttCsv,
        isCsv: true,
      );

      expect(success, isTrue);
      expect(dbManager.getTotalCount(), 2);
    });

    test('syncFromFederalData com payloads vazios deve falhar graciosamente', () async {
      final success = await syncService.syncFromFederalData(
        dnitPayload: '',
        anttPayload: '',
      );

      expect(success, isFalse);
    });

    test('syncFromRemote deve utilizar SyncMirrorManager se fornecido', () async {
      final mockMirror = SyncMirrorManager(
        client: mockClient,
        mirrors: ['https://mirror.test/api'],
      );

      when(() => mockClient.post(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(validOverpassJson, 200));

      final mirrorSyncService = PoiSyncService(
        db,
        mirrorManager: mockMirror,
      );

      final success = await mirrorSyncService.syncFromRemote();
      expect(success, isTrue);
      expect(dbManager.getTotalCount(), 2);

      mirrorSyncService.dispose();
    });

    test('startInAppUpdate deve disparar syncFromRemote', () async {
      when(() => mockClient.post(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(validOverpassJson, 200));

      final success = await syncService.startInAppUpdate();
      expect(success, isTrue);
    });

    test('syncFromFederalData deve suportar JSON e classificar categorias', () async {
      const dnitJson = '''
      {
        "result": {
          "records": [
            {
              "_id": 801,
              "tipo_equipamento": "Radar Fixo",
              "velocidade_regulamentada": 60,
              "latitude": -23.55,
              "longitude": -46.63,
              "sentido": "Crescente"
            }
          ]
        }
      }
      ''';
      const anttJson = '''
      {
        "result": {
          "records": [
            {
              "id": 802,
              "tipo_praca": "Free Flow",
              "latitude": -23.46,
              "longitude": -46.53
            }
          ]
        }
      }
      ''';

      final success = await syncService.syncFromFederalData(
        dnitPayload: dnitJson,
        anttPayload: anttJson,
        isCsv: false,
      );

      expect(success, isTrue);
      expect(dbManager.getTotalCount(), 2);
    });
  });
}
