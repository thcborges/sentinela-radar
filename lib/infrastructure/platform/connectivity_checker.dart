import 'dart:async';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';

/// Contrato desacoplado para verificação de conectividade e Wi-Fi.
abstract class NetworkConnectivityChecker {
  /// Retorna se há qualquer acesso à rede (Wi-Fi, dados móveis ou ethernet).
  Future<bool> isConnected();

  /// Retorna se o dispositivo está conectado via Wi-Fi ou rede ilimitada.
  Future<bool> isWifiConnected();

  /// Fluxo de mudanças no status de conectividade (true = conectado, false = desconectado).
  Stream<bool> get onConnectivityChanged;
}

/// Implementação de hardware do [NetworkConnectivityChecker] utilizando o plugin `connectivity_plus`.
class PlatformConnectivityChecker implements NetworkConnectivityChecker {
  final ConnectivityPlatform? _platform;

  PlatformConnectivityChecker({ConnectivityPlatform? platform})
      : _platform = platform;

  ConnectivityPlatform get _conn =>
      _platform ?? ConnectivityPlatform.instance;

  @override
  Future<bool> isConnected() async {
    try {
      final results = await _conn.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isWifiConnected() async {
    try {
      final results = await _conn.checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _conn.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }
}
