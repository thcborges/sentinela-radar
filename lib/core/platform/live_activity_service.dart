import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import '../engine/alert_machine.dart';
import '../models/poi_model.dart';

/// Modelo de dados imutável transmitido para a Live Activity / Dynamic Island (iOS 16.1+).
class LiveActivityData extends Equatable {
  final double currentSpeedKmh;
  final int? speedLimitKmh;
  final AlertStatus alertStatus;
  final PoiType? poiType;
  final double? distanceMeters;
  final String? roadName;
  final bool isAlertActive;

  const LiveActivityData({
    required this.currentSpeedKmh,
    this.speedLimitKmh,
    required this.alertStatus,
    this.poiType,
    this.distanceMeters,
    this.roadName,
    required this.isAlertActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'currentSpeedKmh': currentSpeedKmh,
      'speedLimitKmh': speedLimitKmh,
      'alertStatus': alertStatus.name,
      'poiType': poiType?.name,
      'distanceMeters': distanceMeters,
      'roadName': roadName,
      'isAlertActive': isAlertActive,
    };
  }

  @override
  List<Object?> get props => [
        currentSpeedKmh,
        speedLimitKmh,
        alertStatus,
        poiType,
        distanceMeters,
        roadName,
        isAlertActive,
      ];
}

/// Contrato abstrato do adaptador de Live Activities nativas.
abstract class LiveActivityPlatformInterface {
  Future<bool> isSupported();
  Future<bool> startActivity(LiveActivityData data);
  Future<bool> updateActivity(LiveActivityData data);
  Future<bool> stopActivity();
}

/// Implementação Fake em memória para testes herméticos em Linux / CI.
class FakeLiveActivityPlatform implements LiveActivityPlatformInterface {
  bool supported;
  LiveActivityData? lastData;

  FakeLiveActivityPlatform({this.supported = true});

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> startActivity(LiveActivityData data) async {
    lastData = data;
    return true;
  }

  @override
  Future<bool> updateActivity(LiveActivityData data) async {
    lastData = data;
    return true;
  }

  @override
  Future<bool> stopActivity() async {
    lastData = null;
    return true;
  }
}

/// Adaptador concreto via MethodChannel nativo para Live Activities (iOS 16.1+).
class PlatformLiveActivityAdapter implements LiveActivityPlatformInterface {
  static const MethodChannel _channel =
      MethodChannel('sentinela/live_activities');

  @override
  Future<bool> isSupported() async {
    try {
      final bool? supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> startActivity(LiveActivityData data) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'startActivity',
        data.toMap(),
      );
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> updateActivity(LiveActivityData data) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'updateActivity',
        data.toMap(),
      );
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopActivity() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('stopActivity');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }
}

/// Serviço de orquestração do ciclo de vida das Live Activities e Dynamic Island.
class LiveActivityService {
  final LiveActivityPlatformInterface _platform;
  bool _isActive = false;
  LiveActivityData? _currentData;

  LiveActivityService({LiveActivityPlatformInterface? platform})
      : _platform = platform ?? PlatformLiveActivityAdapter();

  bool get isActive => _isActive;
  LiveActivityData? get currentData => _currentData;

  Future<bool> isSupported() => _platform.isSupported();

  Future<bool> startActivity(LiveActivityData data) async {
    final supported = await _platform.isSupported();
    if (!supported) return false;

    final success = await _platform.startActivity(data);
    if (success) {
      _isActive = true;
      _currentData = data;
    }
    return success;
  }

  Future<bool> updateActivity(LiveActivityData data) async {
    if (!_isActive) {
      return startActivity(data);
    }
    final success = await _platform.updateActivity(data);
    if (success) {
      _currentData = data;
    }
    return success;
  }

  Future<bool> stopActivity() async {
    if (!_isActive) return true;
    final success = await _platform.stopActivity();
    if (success) {
      _isActive = false;
      _currentData = null;
    }
    return success;
  }
}
