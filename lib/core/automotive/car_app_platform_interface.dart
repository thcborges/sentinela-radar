import 'dart:async';
import 'package:flutter/services.dart';
import 'car_app_models.dart';

/// Contrato abstrato para comunicação com subsistemas automotivos nativos (Android Auto & Apple CarPlay).
abstract class CarAppPlatformInterface {
  Future<bool> isAvailable();
  Future<CarConnectionStatus> getConnectionStatus();
  Stream<CarConnectionStatus> get connectionStream;
  Future<bool> startSession();
  Future<bool> updateDisplay(CarAppData data);
  Future<bool> stopSession();
  void setActionHandler(void Function(CarAction action) handler);
}

/// Implementação Fake em memória para testes herméticos em Linux / CI.
class FakeCarAppPlatform implements CarAppPlatformInterface {
  bool available;
  CarConnectionStatus _status;
  bool isSessionActive = false;
  CarAppData? lastData;
  void Function(CarAction action)? _actionHandler;
  final StreamController<CarConnectionStatus> _statusController =
      StreamController<CarConnectionStatus>.broadcast();

  FakeCarAppPlatform({
    this.available = true,
    CarConnectionStatus initialStatus = CarConnectionStatus.disconnected,
  }) : _status = initialStatus;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<CarConnectionStatus> getConnectionStatus() async => _status;

  @override
  Stream<CarConnectionStatus> get connectionStream => _statusController.stream;

  void setSimulatedConnectionStatus(CarConnectionStatus status) {
    _status = status;
    if (!status.isConnected) {
      isSessionActive = false;
    }
    _statusController.add(status);
  }

  @override
  Future<bool> startSession() async {
    isSessionActive = true;
    return true;
  }

  @override
  Future<bool> updateDisplay(CarAppData data) async {
    lastData = data;
    return true;
  }

  @override
  Future<bool> stopSession() async {
    isSessionActive = false;
    return true;
  }

  @override
  void setActionHandler(void Function(CarAction action) handler) {
    _actionHandler = handler;
  }

  void simulateCarAction(CarAction action) {
    _actionHandler?.call(action);
  }

  void dispose() {
    _statusController.close();
  }
}

/// Adaptador concreto via canais de plataforma nativos para Android Auto e Apple CarPlay.
class PlatformCarAppAdapter implements CarAppPlatformInterface {
  static const MethodChannel _methodChannel = MethodChannel('sentinela/car_app');
  static const EventChannel _eventChannel = EventChannel('sentinela/car_app_events');

  void Function(CarAction action)? _actionHandler;

  PlatformCarAppAdapter() {
    _methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onCarAction') {
      final actionName = call.arguments as String?;
      if (actionName != null) {
        _actionHandler?.call(CarAction.fromName(actionName));
      }
    }
    return null;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CarConnectionStatus> getConnectionStatus() async {
    try {
      final String? result =
          await _methodChannel.invokeMethod<String>('getConnectionStatus');
      if (result == null) return CarConnectionStatus.disconnected;
      return CarConnectionStatus.values.firstWhere(
        (c) => c.name == result,
        orElse: () => CarConnectionStatus.disconnected,
      );
    } catch (_) {
      return CarConnectionStatus.disconnected;
    }
  }

  @override
  Stream<CarConnectionStatus> get connectionStream {
    try {
      return _eventChannel
          .receiveBroadcastStream()
          .map<CarConnectionStatus>((dynamic event) {
        final String? str = event as String?;
        if (str == null) return CarConnectionStatus.disconnected;
        return CarConnectionStatus.values.firstWhere(
          (c) => c.name == str,
          orElse: () => CarConnectionStatus.disconnected,
        );
      });
    } catch (_) {}
    return const Stream.empty();
  }

  @override
  Future<bool> startSession() async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('startSession');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> updateDisplay(CarAppData data) async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>(
        'updateDisplay',
        data.toMap(),
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopSession() async {
    try {
      final bool? result = await _methodChannel.invokeMethod<bool>('stopSession');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void setActionHandler(void Function(CarAction action) handler) {
    _actionHandler = handler;
  }
}
