import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';

/// Sonar Circular Frontal Material Design 3 Dark HUD para aproximação de POIs.
class SonarRadarM3 extends StatelessWidget {
  final List<SonarPoiItem> items;
  final double maxRangeMeters;

  const SonarRadarM3({
    super.key,
    required this.items,
    this.maxRangeMeters = 1000.0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sonar frontal de radar',
      value: '${items.length} pontos detectados à frente no radar',
      child: Card(
      color: SentinelaTheme.surfaceContainerDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF262626), width: 1),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Cabeçalho do Sonar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SentinelaTheme.alertNormal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'SONAR FRONTAL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  items.isEmpty
                      ? 'Alcance: ${maxRangeMeters.toInt()}m'
                      : '${items.length} pontos à frente',
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Grade Gráfica do Sonar
            Expanded(
              child: CustomPaint(
                key: const Key('sonar_radar_canvas'),
                size: const Size(double.infinity, double.infinity),
                painter: SonarCanvasPainter(
                  items: items,
                  maxRangeMeters: maxRangeMeters,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

/// CustomPainter para renderizar o sonar em arco semi-circular e os POIs mapeados.
class SonarCanvasPainter extends CustomPainter {
  final List<SonarPoiItem> items;
  final double maxRangeMeters;

  SonarCanvasPainter({
    required this.items,
    required this.maxRangeMeters,
  });

  /// Alcance máximo efetivo: adapta-se dinamicamente caso existam pontos remotos além de [maxRangeMeters].
  double get effectiveMaxRange {
    if (items.isEmpty) return maxRangeMeters;
    final maxItemDist = items.map((e) => e.distanceMeters).reduce(math.max);
    return math.max(maxRangeMeters, maxItemDist);
  }

  /// Retorna o raio radial proporcional (em pixels) para o item de POI com distinção de profundidade.
  double computeRadialDistance(SonarPoiItem item, double maxRadius) {
    final effectiveMax = effectiveMaxRange;
    final ratio = (item.distanceMeters / effectiveMax).clamp(0.05, 1.0);
    return maxRadius * ratio;
  }

  /// Retorna a coordenada cartesiana (Offset) do centro do POI no Canvas.
  Offset computePoiPosition(SonarPoiItem item, Size size) {
    final origin = Offset(size.width / 2, size.height - 12);
    final maxRadius = math.min(size.width / 2 - 12, size.height - 24);
    if (maxRadius <= 0) return origin;

    final r = computeRadialDistance(item, maxRadius);
    final rad = (item.relativeAngleDeg - 90.0) * (math.pi / 180.0);

    return Offset(
      origin.dx + r * math.cos(rad),
      origin.dy + r * math.sin(rad),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Origem na base central do canvas
    final origin = Offset(size.width / 2, size.height - 12);
    final maxRadius = math.min(size.width / 2 - 12, size.height - 24);

    if (maxRadius <= 0) return;

    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Arcos concêntricos de distância (25%, 50%, 75%, 100%)
    for (int i = 1; i <= 4; i++) {
      final r = maxRadius * (i / 4.0);
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: r),
        math.pi, // de 180° a 0° (semi-círculo frontal superior)
        math.pi,
        false,
        gridPaint,
      );
    }

    // 2. Linhas radiais de rumo angular (0°, ±30°, ±60°)
    for (final deg in [-60.0, -30.0, 0.0, 30.0, 60.0]) {
      final rad = (deg - 90.0) * (math.pi / 180.0);
      final dest = Offset(
        origin.dx + maxRadius * math.cos(rad),
        origin.dy + maxRadius * math.sin(rad),
      );
      canvas.drawLine(origin, dest, gridPaint);
    }

    // 3. Indicador do Veículo (triângulo verde na base)
    final vehiclePaint = Paint()
      ..color = SentinelaTheme.alertNormal
      ..style = PaintingStyle.fill;

    final vehiclePath = Path()
      ..moveTo(origin.dx, origin.dy - 10)
      ..lineTo(origin.dx - 6, origin.dy + 4)
      ..lineTo(origin.dx + 6, origin.dy + 4)
      ..close();

    canvas.drawPath(vehiclePath, vehiclePaint);

    // 4. Marcadores de POIs mapeados no cone polar com gradiente visual de profundidade
    final currentEffectiveMax = effectiveMaxRange;
    for (final item in items) {
      final poiPos = computePoiPosition(item, size);
      final ratio = (item.distanceMeters / currentEffectiveMax).clamp(0.05, 1.0);
      final Color poiColor = _colorForPoiType(item.poi.type);

      // Gradiente de profundidade visual: pontos remotos têm atenuação sutil de halo e diâmetro
      final depthFactor = (1.0 - (ratio * 0.35)).clamp(0.55, 1.0);

      // Efeito de halo/brilho
      final haloPaint = Paint()
        ..color = poiColor.withValues(alpha: 0.3 * depthFactor)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(poiPos, 8.0 * depthFactor, haloPaint);

      // Ponto central de alto contraste
      final dotPaint = Paint()
        ..color = poiColor.withValues(alpha: depthFactor)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(poiPos, (4.0 * depthFactor).clamp(2.5, 4.0), dotPaint);
    }
  }

  Color _colorForPoiType(PoiType type) {
    if (type.isSpeedEnforcement) return SentinelaTheme.alertWarning;
    if (type.isRedLightEnforcement) return const Color(0xFFFF5722);
    if (type.isSpeedBump) return const Color(0xFFFFEB3B);
    if (type.isToll) return SentinelaTheme.alertInfo;
    return const Color(0xFF00E5FF);
  }

  @override
  bool shouldRepaint(covariant SonarCanvasPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.maxRangeMeters != maxRangeMeters;
  }
}
