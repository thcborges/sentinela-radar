import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/l10n/app_language.dart';
import 'package:sentinela/core/l10n/app_localizations.dart';
import 'package:sentinela/core/models/poi_model.dart';

void main() {
  group('AppLanguage Enum Tests', () {
    test('deve retornar códigos e nomes corretos para os 3 idiomas', () {
      expect(AppLanguage.pt.localeCode, 'pt_BR');
      expect(AppLanguage.pt.displayName, 'Português');

      expect(AppLanguage.en.localeCode, 'en_US');
      expect(AppLanguage.en.displayName, 'English');

      expect(AppLanguage.es.localeCode, 'es_ES');
      expect(AppLanguage.es.displayName, 'Español');
    });

    test('fromCode deve resolver strings corretamente', () {
      expect(AppLanguage.fromCode('pt'), AppLanguage.pt);
      expect(AppLanguage.fromCode('pt_BR'), AppLanguage.pt);
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('en_US'), AppLanguage.en);
      expect(AppLanguage.fromCode('es'), AppLanguage.es);
      expect(AppLanguage.fromCode('es_ES'), AppLanguage.es);
      expect(AppLanguage.fromCode('unknown'), AppLanguage.pt); // fallback
    });
  });

  group('AppLocalizations Tests (BDD - i18n & l10n)', () {
    test('deve traduzir categorias de POI em Português', () {
      final loc = AppLocalizations(AppLanguage.pt);
      expect(loc.poiTypeName(PoiType.fixedRadar), 'Radar Fixo');
      expect(loc.poiTypeName(PoiType.mobileRadar), 'Radar Móvel');
      expect(loc.poiTypeName(PoiType.trafficLightRadar), 'Semáforo com Radar');
      expect(loc.poiTypeName(PoiType.redLightCamera), 'Avanço de Sinal');
      expect(loc.poiTypeName(PoiType.electronicSpeedBump), 'Lombada Eletrônica');
      expect(loc.poiTypeName(PoiType.physicalSpeedBump), 'Lombada Física');
      expect(loc.poiTypeName(PoiType.tollBooth), 'Praça de Pedágio');
      expect(loc.poiTypeName(PoiType.freeFlowToll), 'Pórtico Free Flow');
      expect(loc.poiTypeName(PoiType.highwayPatrol), 'Polícia Rodoviária');
    });

    test('deve traduzir categorias de POI em Inglês', () {
      final loc = AppLocalizations(AppLanguage.en);
      expect(loc.poiTypeName(PoiType.fixedRadar), 'Fixed Speed Camera');
      expect(loc.poiTypeName(PoiType.mobileRadar), 'Mobile Radar');
      expect(loc.poiTypeName(PoiType.trafficLightRadar), 'Traffic Light Camera');
      expect(loc.poiTypeName(PoiType.redLightCamera), 'Red Light Camera');
      expect(loc.poiTypeName(PoiType.electronicSpeedBump), 'Electronic Speed Bump');
      expect(loc.poiTypeName(PoiType.physicalSpeedBump), 'Speed Bump');
      expect(loc.poiTypeName(PoiType.tollBooth), 'Toll Plaza');
      expect(loc.poiTypeName(PoiType.freeFlowToll), 'Free Flow Toll Gantry');
      expect(loc.poiTypeName(PoiType.highwayPatrol), 'Highway Patrol');
    });

    test('deve traduzir categorias de POI em Espanhol', () {
      final loc = AppLocalizations(AppLanguage.es);
      expect(loc.poiTypeName(PoiType.fixedRadar), 'Radar Fijo');
      expect(loc.poiTypeName(PoiType.mobileRadar), 'Radar Móvil');
      expect(loc.poiTypeName(PoiType.trafficLightRadar), 'Semáforo con Radar');
      expect(loc.poiTypeName(PoiType.redLightCamera), 'Cámara de Semáforo');
      expect(loc.poiTypeName(PoiType.electronicSpeedBump), 'Reductor Electrónico');
      expect(loc.poiTypeName(PoiType.physicalSpeedBump), 'Resalto / Badén');
      expect(loc.poiTypeName(PoiType.tollBooth), 'Peaje');
      expect(loc.poiTypeName(PoiType.freeFlowToll), 'Pórtico Free Flow');
      expect(loc.poiTypeName(PoiType.highwayPatrol), 'Policía de Carreteras');
    });

    test('deve conter traduções para UI essenciais nas 3 línguas', () {
      final pt = AppLocalizations(AppLanguage.pt);
      final en = AppLocalizations(AppLanguage.en);
      final es = AppLocalizations(AppLanguage.es);

      expect(pt.speedUnit, 'km/h');
      expect(en.speedUnit, 'km/h');
      expect(es.speedUnit, 'km/h');

      expect(pt.reduceSpeedWarning, contains('Reduza a velocidade'));
      expect(en.reduceSpeedWarning, contains('Reduce your speed'));
      expect(es.reduceSpeedWarning, contains('Reduzca la velocidad'));

      expect(pt.hapticFeedbackTitle, 'Feedback Háptico (Vibração)');
      expect(en.hapticFeedbackTitle, 'Haptic Feedback (Vibration)');
      expect(es.hapticFeedbackTitle, 'Respuesta Háptica (Vibración)');

      expect(pt.highContrastTitle, 'Modo Alto Contraste');
      expect(en.highContrastTitle, 'High Contrast Mode');
      expect(es.highContrastTitle, 'Modo Alto Contraste');

      // Additional UI Strings
      expect(pt.metersUnit, 'm');
      expect(pt.appTitle, 'Sentinela');
      expect(pt.monitoringRoads, 'Monitorando vias...');
      expect(en.monitoringRoads, 'Monitoring roads...');
      expect(es.monitoringRoads, 'Monitoreando vías...');

      expect(pt.speedLimitPrefix, 'Máx');
      expect(en.speedLimitPrefix, 'Max');

      expect(pt.tunnelDeadReckoning, contains('Modo Túnel'));
      expect(en.tunnelDeadReckoning, contains('Tunnel Mode'));

      expect(pt.gpsSignalSearching, contains('Buscando sinal'));
      expect(en.gpsSignalSearching, contains('Searching GPS'));

      expect(pt.gpsSignalOk, contains('Sinal GPS Ativo'));
      expect(en.gpsSignalOk, contains('GPS Signal Active'));

      expect(pt.mirrorModeActive, contains('HUD'));
      expect(en.mirrorModeActive, contains('HUD'));

      expect(pt.reportPoiTooltip, contains('Reportar'));
      expect(en.reportPoiTooltip, contains('Quick Report'));

      expect(pt.languageSectionTitle, contains('Idioma'));
      expect(en.languageSectionTitle, contains('Language'));

      expect(pt.hapticFeedbackSubtitle, contains('táteis'));
      expect(en.hapticFeedbackSubtitle, contains('Tactile'));

      expect(pt.highContrastSubtitle, contains('contraste'));
      expect(en.highContrastSubtitle, contains('contrast'));

      expect(pt.speedToleranceTitle, contains('Tolerância'));
      expect(en.speedToleranceTitle, contains('Tolerance'));

      expect(pt.alertOnlyOverSpeedTitle, contains('excesso'));
      expect(en.alertOnlyOverSpeedTitle, contains('over speed'));
    });

    test('AppLocalizationsDelegate deve suportar reload e idiomas corretos', () {
      const delegate = AppLocalizationsDelegate();
      expect(delegate.isSupported(const Locale('pt')), isTrue);
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('es')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isFalse);
      expect(delegate.shouldReload(delegate), isFalse);
    });

    testWidgets('AppLocalizations.of deve resolver a partir do BuildContext', (tester) async {
      late AppLocalizations loc;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
          ],
          home: Builder(
            builder: (context) {
              loc = AppLocalizations.of(context);
              return Text(loc.settingsTitle);
            },
          ),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(loc.language, AppLanguage.en);
    });
  });
}
