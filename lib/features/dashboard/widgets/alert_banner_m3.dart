import 'package:flutter/material.dart';
import 'package:sentinela/core/engine/alert_machine.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';

/// Card de Notificação de Alerta Ativo em Material Design 3 Dark HUD.
class AlertBannerM3 extends StatelessWidget {
  final ActiveAlert? activeAlert;
  final AlertStatus status;

  const AlertBannerM3({
    super.key,
    required this.activeAlert,
    this.status = AlertStatus.idle,
  });

  @override
  Widget build(BuildContext context) {
    if (activeAlert == null || status == AlertStatus.idle) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: SentinelaTheme.surfaceContainerDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF222222), width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_rounded,
              color: SentinelaTheme.alertNormal,
              size: 18,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Via Segura • Monitoramento Ativo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final alert = activeAlert!;
    final isCritical = status == AlertStatus.overSpeed;
    final alertColor = SentinelaTheme.colorForAlertStatus(status);

    final String distanceFormatted = alert.distanceMeters >= 1000
        ? '${(alert.distanceMeters / 1000.0).toStringAsFixed(1)} km'
        : '${alert.distanceMeters.round()} m';

    final alertLabel = 'Alerta de ${alert.poi.type.displayName}. '
        '${isCritical ? "Atenção: Reduza a velocidade. " : ""}'
        'Distância: $distanceFormatted.'
        '${alert.poi.speedLimit != null ? " Limite: ${alert.poi.speedLimit} km/h." : ""}';

    return Semantics(
      liveRegion: true,
      label: alertLabel,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFF2C0A0E) : const Color(0xFF221C0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alertColor,
          width: isCritical ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: alertColor.withValues(alpha: isCritical ? 0.35 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCritical)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: SentinelaTheme.alertCritical,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'REDUZA A VELOCIDADE',
                    style: TextStyle(
                      color: SentinelaTheme.alertCritical,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForPoiType(alert.poi.type),
                  color: alertColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.poi.type.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (alert.poi.roadName.isNotEmpty)
                      Text(
                        alert.poi.roadName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    distanceFormatted,
                    style: TextStyle(
                      color: alertColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (alert.poi.speedLimit != null)
                    Text(
                      'Limite: ${alert.poi.speedLimit} km/h',
                      style: const TextStyle(
                        color: Color(0xFF8E8E8E),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  IconData _iconForPoiType(PoiType type) {
    if (type.isSpeedEnforcement) return Icons.speed_rounded;
    if (type.isRedLightEnforcement) return Icons.traffic_rounded;
    if (type.isSpeedBump) return Icons.warning_amber_rounded;
    if (type.isToll) return Icons.toll_rounded;
    return Icons.local_police_rounded;
  }
}
