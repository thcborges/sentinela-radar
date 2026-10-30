import 'dart:async';
import '../../../core/engine/alert_machine.dart';

/// Adaptador abstrato de plataforma para o Overlay (janela flutuante).
/// Permite isolamento total e testes herméticos em ambiente headless Linux (CI).
abstract class OverlayPlatformAdapter {
  Future<bool> isPermissionGranted();
  Future<bool> requestPermission();
  Future<bool> showOverlay({int height = 80, int width = 240});
  Future<bool> closeOverlay();
  Future<void> shareData(Map<String, dynamic> data);
}

/// Serviço de orquestração do Overlay Flutuante (Picture-in-Picture / System Alert Window).
/// Gerencia ciclo de vida, permissões do sistema operacional e despacho de telemetria.
class OverlayService {
  final OverlayPlatformAdapter _adapter;
  bool _isOverlayOpen = false;

  OverlayService({required OverlayPlatformAdapter adapter}) : _adapter = adapter;

  /// Retorna se a janela flutuante está ativa e visível na tela.
  bool get isOverlayOpen => _isOverlayOpen;

  /// Verifica se o aplicativo possui a permissão especial de sobreposição (SYSTEM_ALERT_WINDOW).
  Future<bool> checkPermission() => _adapter.isPermissionGranted();

  /// Solicita ao usuário a permissão de sobrepor a outros aplicativos.
  Future<bool> requestPermission() => _adapter.requestPermission();

  /// Abre a janela flutuante, solicitando permissão previamente caso ainda não concedida.
  Future<bool> startOverlay() async {
    final granted = await _adapter.isPermissionGranted();
    if (!granted) {
      final requested = await _adapter.requestPermission();
      if (!requested) return false;
    }

    final shown = await _adapter.showOverlay();
    if (shown) {
      _isOverlayOpen = true;
    }
    return shown;
  }

  /// Fecha a janela flutuante e libera os recursos nativos.
  Future<bool> stopOverlay() async {
    final closed = await _adapter.closeOverlay();
    if (closed) {
      _isOverlayOpen = false;
    }
    return closed;
  }

  /// Despacha dados atualizados de telemetria e alertas ativos para a janela flutuante.
  Future<void> updateOverlayData({
    required double speedKmh,
    ActiveAlert? alert,
  }) async {
    if (!_isOverlayOpen) return;

    await _adapter.shareData({
      'speed': speedKmh,
      'hasAlert': alert != null,
      'isOverSpeed': alert?.isOverSpeed ?? false,
      'distanceMeters': alert?.distanceMeters,
      'speedLimit': alert?.poi.speedLimit,
      'poiType': alert?.poi.type.name,
    });
  }
}
