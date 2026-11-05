import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('AlertPreferences POI Type Selection', () {
    test('deve inicializar com todas as categorias de POIs ativas por padrão', () {
      const prefs = AlertPreferences();
      expect(prefs.enabledPoiTypes.length, equals(PoiType.values.length));
      for (final type in PoiType.values) {
        expect(prefs.isPoiTypeEnabled(type), isTrue);
      }
    });

    test('deve permitir desativar e ativar categorias individuais de POI', () {
      const prefs = AlertPreferences();

      // Desativa radar móvel e lombada física
      final updated = prefs
          .togglePoiType(PoiType.mobileRadar, false)
          .togglePoiType(PoiType.physicalSpeedBump, false);

      expect(updated.isPoiTypeEnabled(PoiType.mobileRadar), isFalse);
      expect(updated.isPoiTypeEnabled(PoiType.physicalSpeedBump), isFalse);
      expect(updated.isPoiTypeEnabled(PoiType.fixedRadar), isTrue);
      expect(updated.isPoiTypeEnabled(PoiType.trafficLightRadar), isTrue);
      expect(updated.isPoiTypeEnabled(PoiType.redLightCamera), isTrue);
      expect(updated.isPoiTypeEnabled(PoiType.tollBooth), isTrue);

      // Reativa radar móvel
      final reenabled = updated.togglePoiType(PoiType.mobileRadar, true);
      expect(reenabled.isPoiTypeEnabled(PoiType.mobileRadar), isTrue);
      expect(reenabled.isPoiTypeEnabled(PoiType.physicalSpeedBump), isFalse);
    });

    test('deve serializar e desserializar enabledPoiTypes em JSON para persistência e backup', () {
      final customTypes = {
        PoiType.fixedRadar,
        PoiType.trafficLightRadar,
        PoiType.tollBooth,
        PoiType.freeFlowToll,
      };

      final prefs = const AlertPreferences().copyWith(
        enabledPoiTypes: customTypes,
      );

      final json = prefs.toJson();
      expect(json['enabledPoiTypes'], isA<List>());
      final list = json['enabledPoiTypes'] as List;
      expect(list, contains('fixedRadar'));
      expect(list, contains('trafficLightRadar'));
      expect(list, contains('tollBooth'));
      expect(list, contains('freeFlowToll'));
      expect(list.contains('mobileRadar'), isFalse);

      final restored = AlertPreferences.fromJson(json);
      expect(restored.enabledPoiTypes, equals(customTypes));
      expect(restored.isPoiTypeEnabled(PoiType.fixedRadar), isTrue);
      expect(restored.isPoiTypeEnabled(PoiType.mobileRadar), isFalse);
      expect(restored.isPoiTypeEnabled(PoiType.tollBooth), isTrue);
    });
  });
}
