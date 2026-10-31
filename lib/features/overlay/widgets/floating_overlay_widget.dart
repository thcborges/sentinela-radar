import 'package:flutter/material.dart';
import '../../../core/engine/alert_machine.dart';
import '../../../core/models/poi_model.dart';
import '../../../core/theme/sentinela_theme.dart';

/// Miniatura Flutuante (Overlay / PiP) no padrão Material Design 3 Dark HUD.
/// Projetada para sobreposição a navegadores GPS com dimensões ultracompactas
/// e alta legibilidade sob luz solar direta ou condução noturna.
class FloatingOverlayWidget extends StatelessWidget {
  final double currentSpeedKmh;
  final ActiveAlert? activeAlert;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final VoidCallback? onQuickReport;

  const FloatingOverlayWidget({
    super.key,
    required this.currentSpeedKmh,
    this.activeAlert,
    this.onTap,
    this.onClose,
    this.onQuickReport,
  });

  Color _getBorderColor() {
    if (activeAlert == null) return SentinelaTheme.alertNormal.withValues(alpha: 0.5);
    if (activeAlert!.isOverSpeed) return SentinelaTheme.alertCritical;
    if (activeAlert!.poi.type == PoiType.tollBooth ||
        activeAlert!.poi.type == PoiType.freeFlowToll ||
        activeAlert!.poi.type == PoiType.highwayPatrol) {
      return SentinelaTheme.alertInfo;
    }
    return SentinelaTheme.alertWarning;
  }

  IconData _getPoiIcon(PoiType type) {
    switch (type) {
      case PoiType.fixedRadar:
      case PoiType.mobileRadar:
        return Icons.camera_alt_rounded;
      case PoiType.trafficLightRadar:
      case PoiType.redLightCamera:
        return Icons.traffic_rounded;
      case PoiType.electronicSpeedBump:
      case PoiType.physicalSpeedBump:
        return Icons.waves_rounded;
      case PoiType.tollBooth:
      case PoiType.freeFlowToll:
        return Icons.toll_rounded;
      case PoiType.highwayPatrol:
        return Icons.local_police_rounded;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();
    final alert = activeAlert;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xE61E1E1E), // Dark HUD translúcido (90%)
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor,
              width: alert != null && alert.isOverSpeed ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: alert != null ? 0.35 : 0.15),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Velocímetro Compacto
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentSpeedKmh.round()}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: alert != null && alert.isOverSpeed
                          ? SentinelaTheme.alertCritical
                          : Colors.white,
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 10),

              // Seção de Alerta Ativo ou Estado Neutro
              if (alert != null) ...[
                Container(
                  height: 32,
                  width: 1,
                  color: Colors.white24,
                ),
                const SizedBox(width: 10),
                Icon(
                  _getPoiIcon(alert.poi.type),
                  color: borderColor,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDistance(alert.distanceMeters),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: borderColor,
                  ),
                ),
                if (alert.poi.speedLimit != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.red, width: 2.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${alert.poi.speedLimit}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                const Icon(
                  Icons.navigation_rounded,
                  color: SentinelaTheme.alertNormal,
                  size: 18,
                ),
              ],

              if (onQuickReport != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  key: const Key('overlay_quick_report_button'),
                  onTap: onQuickReport,
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.add_location_alt_rounded,
                      color: SentinelaTheme.primaryGold,
                      size: 18,
                    ),
                  ),
                ),
              ],

              if (onClose != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
