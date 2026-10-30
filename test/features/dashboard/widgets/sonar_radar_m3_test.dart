import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/dashboard/widgets/sonar_radar_m3.dart';

void main() {
  group('SonarRadarM3 Widget (Material Design 3 Dark HUD)', () {
    testWidgets('deve renderizar tela de sonar com CustomPaint quando lista for vazia', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: const Scaffold(
            body: SonarRadarM3(
              items: [],
              maxRangeMeters: 1000,
            ),
          ),
        ),
      );

      final customPaintFinder = find.byKey(const Key('sonar_radar_canvas'));
      expect(customPaintFinder, findsOneWidget);
      expect(find.text('Alcance: 1000m'), findsOneWidget);
    });

    testWidgets('deve renderizar pontos no sonar com POIs de diferentes categorias', (tester) async {
      const radarPoi = PoiPoint(
        id: 1,
        latitude: -23.55,
        longitude: -46.63,
        type: PoiType.fixedRadar,
        speedLimit: 80,
      );

      const tollPoi = PoiPoint(
        id: 2,
        latitude: -23.56,
        longitude: -46.64,
        type: PoiType.tollBooth,
      );

      final items = [
        const SonarPoiItem(
          poi: radarPoi,
          distanceMeters: 450,
          relativeAngleDeg: 15,
        ),
        const SonarPoiItem(
          poi: tollPoi,
          distanceMeters: 800,
          relativeAngleDeg: -20,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: Scaffold(
            body: SonarRadarM3(
              items: items,
              maxRangeMeters: 1000,
            ),
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byKey(const Key('sonar_radar_canvas')),
      );
      expect(customPaint.painter, isNotNull);
      expect(find.text('2 pontos à frente'), findsOneWidget);
    });
  });
}
