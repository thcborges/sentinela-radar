import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';

/// Velocímetro Digital Material Design 3 de Alto Contraste para Dark HUD.
class SpeedometerM3 extends StatelessWidget {
  final double speedKmh;
  final int? speedLimit;
  final AlertStatus alertStatus;
  final bool isGpsFixValid;
  final double maxSpeed;
  final bool isHighContrast;

  const SpeedometerM3({
    super.key,
    required this.speedKmh,
    this.speedLimit,
    this.alertStatus = AlertStatus.idle,
    this.isGpsFixValid = true,
    this.maxSpeed = 160.0,
    this.isHighContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    final alertColor = SentinelaTheme.colorForAlertStatus(alertStatus);
    final trackColor = isHighContrast ? const Color(0xFF444444) : const Color(0xFF222222);

    return AspectRatio(
      aspectRatio: 1.0,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: isGpsFixValid ? speedKmh : 0.0,
          end: isGpsFixValid ? speedKmh : 0.0,
        ),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, animatedSpeed, child) {
          final ringProgress = isGpsFixValid
              ? (animatedSpeed / maxSpeed).clamp(0.0, 1.0)
              : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Anel dinâmico do velocímetro com interpolação fluida
              CustomPaint(
                key: const Key('speedometer_ring_painter'),
                size: const Size(double.infinity, double.infinity),
                painter: _SpeedometerRingPainter(
                  progress: ringProgress,
                  trackColor: trackColor,
                  activeColor: alertColor,
                  isHighContrast: isHighContrast,
                ),
              ),

              // Mostrador Central (Velocidade ou aviso de GPS)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isGpsFixValid) ...[
                    const Icon(
                      Icons.gps_not_fixed_rounded,
                      color: SentinelaTheme.alertWarning,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Buscando GPS...',
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Semantics(
                      label: 'Velocímetro',
                      value: '${speedKmh.round()} km/h',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text(
                            speedKmh.round().toString(),
                            style: isHighContrast
                                ? SentinelaTheme.speedTextStyle.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  )
                                : SentinelaTheme.speedTextStyle,
                          ),
                          Text(
                            'km/h',
                            style: TextStyle(
                              color: isHighContrast ? Colors.white70 : const Color(0xFF8E8E8E),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Placa de limite de velocidade da via (Sinalização R-19 Brasileira)
                  if (speedLimit != null)
                    Semantics(
                      label: 'Velocidade máxima permitida',
                      value: '$speedLimit km/h',
                      excludeSemantics: true,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD32F2F),
                            width: isHighContrast ? 5.5 : 4.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          speedLimit.toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// CustomPainter para desenhar o anel de velocidade em arco (240 graus).
class _SpeedometerRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color activeColor;
  final bool isHighContrast;

  _SpeedometerRingPainter({
    required this.progress,
    required this.trackColor,
    required this.activeColor,
    this.isHighContrast = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    final strokeWidth = isHighContrast ? 17.0 : 14.0;

    // Arco de 240 graus centralizado na parte superior (de 150° a 390°)
    const startAngle = 150.0 * (math.pi / 180.0);
    const sweepTotal = 240.0 * (math.pi / 180.0);

    // Track de fundo
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    if (progress > 0.0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.isHighContrast != isHighContrast;
  }
}
