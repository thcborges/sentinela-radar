import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Contrato desacoplado para manter a tela do dispositivo ativa durante a condução.
abstract class WakelockManager {
  /// Impede o bloqueio ou escurecimento da tela do aparelho.
  Future<void> enable();

  /// Restaura o comportamento padrão do sistema de desligamento de tela.
  Future<void> disable();

  /// Retorna se o bloqueio de tela está desativado no momento.
  Future<bool> isEnabled();
}

/// Implementação de hardware do [WakelockManager] utilizando o plugin `wakelock_plus`.
class PlatformWakelockManager implements WakelockManager {
  final WakelockPlusPlatformInterface? _platform;

  PlatformWakelockManager({WakelockPlusPlatformInterface? platform})
      : _platform = platform;

  WakelockPlusPlatformInterface get _w =>
      _platform ?? WakelockPlusPlatformInterface.instance;

  @override
  Future<void> enable() async {
    try {
      await _w.toggle(enable: true);
    } catch (_) {
      // Ignora erro em ambientes headless/testes
    }
  }

  @override
  Future<void> disable() async {
    try {
      await _w.toggle(enable: false);
    } catch (_) {
      // Ignora erro em ambientes headless/testes
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      return await _w.enabled;
    } catch (_) {
      return false;
    }
  }
}
