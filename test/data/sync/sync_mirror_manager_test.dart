import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentinela/data/sync/sync_mirror_manager.dart';

void main() {
  group('SyncMirrorManager (Failover de Espelhos de Sincronização)', () {
    test('deve executar requisição com sucesso no espelho primário', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'overpass-api.de') {
          return http.Response('{"elements": []}', 200);
        }
        return http.Response('Error', 500);
      });

      final manager = SyncMirrorManager(
        client: mockClient,
        mirrors: [
          'https://overpass-api.de/api/interpreter',
          'https://overpass.kumi.systems/api/interpreter',
        ],
      );

      final response = await manager.postQueryWithFailover(query: '[out:json];');

      expect(response.statusCode, 200);
      expect(manager.activeMirror, 'https://overpass-api.de/api/interpreter');
      expect(manager.failoverHistory, isEmpty);
    });

    test('deve alternar para o espelho secundário quando o primário retornar erro HTTP', () async {
      final switches = <String>[];
      final mockClient = MockClient((request) async {
        if (request.url.host == 'overpass-api.de') {
          return http.Response('Rate limit exceeded', 429);
        }
        if (request.url.host == 'overpass.kumi.systems') {
          return http.Response('{"elements": [{"id": 1}]}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final manager = SyncMirrorManager(
        client: mockClient,
        mirrors: [
          'https://overpass-api.de/api/interpreter',
          'https://overpass.kumi.systems/api/interpreter',
        ],
        onMirrorSwitched: (failed, next, err) {
          switches.add('$failed -> $next');
        },
      );

      final response = await manager.postQueryWithFailover(query: '[out:json];');

      expect(response.statusCode, 200);
      expect(response.body, contains('"id": 1'));
      expect(manager.activeMirror, 'https://overpass.kumi.systems/api/interpreter');
      expect(switches, [
        'https://overpass-api.de/api/interpreter -> https://overpass.kumi.systems/api/interpreter',
      ]);
      expect(manager.failoverHistory.length, 1);
    });

    test('deve lançar exceção AllMirrorsFailedException se todos os espelhos falharem', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final manager = SyncMirrorManager(
        client: mockClient,
        mirrors: [
          'https://mirror1.org/api',
          'https://mirror2.org/api',
        ],
      );

      expect(
        () => manager.postQueryWithFailover(query: '[out:json];'),
        throwsA(isA<AllMirrorsFailedException>()),
      );
    });

    test('deve permitir resetar para o primeiro espelho e configurar mirrors customizados', () {
      final manager = SyncMirrorManager(
        mirrors: ['https://m1.com', 'https://m2.com'],
      );

      expect(manager.availableMirrors.length, 2);
      expect(manager.activeMirror, 'https://m1.com');

      manager.setActiveMirror('https://m2.com');
      expect(manager.activeMirror, 'https://m2.com');

      manager.resetMirror();
      expect(manager.activeMirror, 'https://m1.com');
      manager.dispose();
    });

    test('AllMirrorsFailedException toString deve formatar mensagem corretamente', () {
      final ex = AllMirrorsFailedException('Falha de conexão', ['https://m1.com']);
      expect(ex.toString(), contains('AllMirrorsFailedException: Falha de conexão'));
      expect(ex.toString(), contains('https://m1.com'));
    });

    test('deve tratar exceção de rede lançada pelo cliente HTTP e chavear espelho', () async {
      int attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          throw Exception('Socket closed');
        }
        return http.Response('{"elements": []}', 200);
      });

      final manager = SyncMirrorManager(
        client: mockClient,
        mirrors: ['https://m1.com', 'https://m2.com'],
      );

      final resp = await manager.postQueryWithFailover(query: '[out:json];');
      expect(resp.statusCode, 200);
      expect(manager.activeMirror, 'https://m2.com');
    });
  });
}
