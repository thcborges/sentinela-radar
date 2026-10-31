import 'dart:async';
import 'package:http/http.dart' as http;

/// Exceção lançada quando todos os espelhos de sincronização configurados falham.
class AllMirrorsFailedException implements Exception {
  final String message;
  final List<String> attemptedMirrors;

  AllMirrorsFailedException(this.message, this.attemptedMirrors);

  @override
  String toString() => 'AllMirrorsFailedException: $message (tentativas: $attemptedMirrors)';
}

/// Gerenciador de espelhos públicos (mirrors) para sincronização da base de POIs
/// com detecção de falha de rota, rate-limit (HTTP 429/500/503) e failover automático.
class SyncMirrorManager {
  static const List<String> defaultMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  final http.Client _client;
  final bool _ownsClient;
  final List<String> _mirrors;
  int _activeMirrorIndex = 0;
  final List<String> _failoverHistory = [];

  final void Function(String failedMirror, String nextMirror, Object error)? onMirrorSwitched;

  SyncMirrorManager({
    http.Client? client,
    List<String>? mirrors,
    this.onMirrorSwitched,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _mirrors = List<String>.from(mirrors ?? defaultMirrors);

  /// Lista de espelhos disponíveis configurados.
  List<String> get availableMirrors => List.unmodifiable(_mirrors);

  /// Espelho atualmente ativo para requisições.
  String get activeMirror => _mirrors[_activeMirrorIndex];

  /// Histórico de registros de failover ocorridos nesta sessão.
  List<String> get failoverHistory => List.unmodifiable(_failoverHistory);

  /// Define manualmente o espelho ativo.
  void setActiveMirror(String mirrorUrl) {
    final idx = _mirrors.indexOf(mirrorUrl);
    if (idx != -1) {
      _activeMirrorIndex = idx;
    }
  }

  /// Redefine o espelho ativo para o espelho prioritário primário.
  void resetMirror() {
    _activeMirrorIndex = 0;
  }

  /// Fecha o cliente HTTP se foi instanciado internamente.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Executa uma query POST de sincronização com failover sequencial entre os espelhos.
  Future<http.Response> postQueryWithFailover({
    required String query,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final attempted = <String>[];
    Object? lastError;

    for (var i = 0; i < _mirrors.length; i++) {
      final currentIdx = (_activeMirrorIndex + i) % _mirrors.length;
      final mirrorUrl = _mirrors[currentIdx];
      attempted.add(mirrorUrl);

      try {
        final uri = Uri.parse(mirrorUrl);
        final response = await _client.post(
          uri,
          body: {'data': query},
          headers: {'User-Agent': 'SentinelaRadar/1.0 (Mobile App; 100% Offline-First)'},
        ).timeout(timeout);

        if (response.statusCode == 200) {
          _activeMirrorIndex = currentIdx;
          return response;
        }

        // Status 429, 500, 502, 503, etc. -> Failover
        lastError = 'HTTP ${response.statusCode}: ${response.body}';
        _handleFailover(mirrorUrl, currentIdx, lastError);
      } catch (e) {
        lastError = e;
        _handleFailover(mirrorUrl, currentIdx, e);
      }
    }

    throw AllMirrorsFailedException(
      'Nenhum espelho de sincronização respondeu com sucesso. Último erro: $lastError',
      attempted,
    );
  }

  void _handleFailover(String failedMirror, int currentIdx, Object error) {
    final nextIdx = (currentIdx + 1) % _mirrors.length;
    final nextMirror = _mirrors[nextIdx];
    _failoverHistory.add('$failedMirror -> $nextMirror');
    onMirrorSwitched?.call(failedMirror, nextMirror, error);
  }
}
