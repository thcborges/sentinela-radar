import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/models/poi_model.dart';
import 'location_service_interface.dart';

/// Implementação de hardware do [LocationService] utilizando o plugin nativo Geolocator.
class GeolocatorLocationService implements LocationService {
  final GeolocatorPlatform? _platform;

  GeolocatorLocationService({GeolocatorPlatform? platform})
      : _platform = platform;

  GeolocatorPlatform get _geo => _platform ?? GeolocatorPlatform.instance;

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await _geo.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    try {
      final perm = await _geo.checkPermission();
      return _mapPermission(perm);
    } catch (_) {
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final perm = await _geo.requestPermission();
      return _mapPermission(perm);
    } catch (_) {
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Stream<VehiclePosition> getPositionStream({
    int distanceFilterMeters = 0,
    int intervalMs = 1000,
  }) {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
        intervalDuration: Duration(milliseconds: intervalMs),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilterMeters,
        timeLimit: null,
      );
    }

    return _geo.getPositionStream(locationSettings: settings).map((pos) {
      final speedMs = pos.speed >= 0 ? pos.speed : 0.0;
      final speedKmh = speedMs * 3.6;
      final heading = pos.heading >= 0 ? pos.heading : 0.0;
      final accuracy = pos.accuracy >= 0 ? pos.accuracy : 5.0;

      return VehiclePosition(
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedKmh: speedKmh,
        bearing: heading,
        accuracyMeters: accuracy,
        timestamp: pos.timestamp,
      );
    });
  }

  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return LocationPermissionStatus.always;
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.whileInUse;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }
}
