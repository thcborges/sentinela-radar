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

    testWidgets('BUG #37 REGRESSÃO: POIs remotos a 850m e 1200m no mesmo azimute devem possuir raios radiais e posições distintas no Canvas', (tester) async {
      const poi850 = PoiPoint(
        id: 10,
        latitude: -23.50,
        longitude: -46.60,
        type: PoiType.fixedRadar,
      );

      const poi1200 = PoiPoint(
        id: 11,
        latitude: -23.48,
        longitude: -46.60,
        type: PoiType.tollBooth,
      );

      final items = [
        const SonarPoiItem(
          poi: poi850,
          distanceMeters: 850.0,
          relativeAngleDeg: 0.0,
        ),
        const SonarPoiItem(
          poi: poi1200,
          distanceMeters: 1200.0,
          relativeAngleDeg: 0.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: SentinelaTheme.darkTheme,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: SonarRadarM3(
                items: items,
                maxRangeMeters: 800.0,
              ),
            ),
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byKey(const Key('sonar_radar_canvas')),
      );
      final painter = customPaint.painter as SonarCanvasPainter;

      final pos850 = painter.computePoiPosition(items[0], const Size(400, 300));
      final pos1200 = painter.computePoiPosition(items[1], const Size(400, 300));

      final origin = Offset(400 / 2, 300 - 12);
      final radius850 = (pos850 - origin).distance;
      final radius1200 = (pos1200 - origin).distance;

      expect(radius850, isNot(equals(radius1200)));
      expect(radius1200, greaterThan(radius850));
      expect(pos850.dy, isNot(equals(pos1200.dy)));
    });
  });
}
