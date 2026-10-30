import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/poi_model.dart';
import '../../../core/theme/sentinela_theme.dart';
import '../bloc/stats_cubit.dart';
import '../models/passage_record.dart';

/// Tela de Estatísticas de Condução e Histórico de Passagens (100% Offline e Privado).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas de Condução'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Limpar Histórico',
            onPressed: () => _confirmClearHistory(context),
          ),
        ],
      ),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = state.summary;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Badge de Privacidade Absoluta
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141F18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SentinelaTheme.alertNormal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: SentinelaTheme.alertNormal,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacidade Absoluta (100% Offline)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Suas velocidades e locais nunca saem da memória do seu celular.',
                            style: TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Grid de Métricas Consolidadas
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Passagens',
                      value: '${summary.totalPassages}',
                      color: Colors.white,
                      icon: Icons.alt_route_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Conformidade',
                      value: '${summary.adherenceRatePercent.toStringAsFixed(1)}%',
                      color: summary.adherenceRatePercent >= 80.0
                          ? SentinelaTheme.alertNormal
                          : SentinelaTheme.alertCritical,
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Excessos',
                      value: '${summary.overSpeedPassages}',
                      color: summary.overSpeedPassages > 0
                          ? SentinelaTheme.alertCritical
                          : SentinelaTheme.alertNormal,
                      icon: Icons.warning_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. Cabeçalho de Passagens Recentes
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Últimas Passagens Registradas',
                  style: TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              // 4. Lista de Passagens ou Estado Vazio
              if (state.recentPassages.isEmpty)
                Card(
                  color: SentinelaTheme.surfaceContainerDark,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Center(
                      child: Text(
                        'Nenhuma passagem registrada ainda.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...state.recentPassages.map((p) => _buildPassageTile(p)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: SentinelaTheme.surfaceContainerDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.6), size: 14),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassageTile(PassageRecord record) {
    final statusColor = record.isOverSpeed
        ? SentinelaTheme.alertCritical
        : SentinelaTheme.alertNormal;

    final formattedTime =
        '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: SentinelaTheme.surfaceContainerDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: record.isOverSpeed
              ? SentinelaTheme.alertCritical.withValues(alpha: 0.5)
              : const Color(0xFF262626),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: 0.15),
              ),
              child: Icon(
                _getIconForType(record.poiType),
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.roadName.isNotEmpty ? record.roadName : record.poiType.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.poiType.label} • $formattedTime',
                    style: const TextStyle(
                      color: Color(0xFF8E8E8E),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.vehicleSpeedKmh.round()} km/h',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: statusColor,
                  ),
                ),
                if (record.speedLimit != null)
                  Text(
                    'Limite: ${record.speedLimit} km/h',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF757575),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(PoiType type) {
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

  void _confirmClearHistory(BuildContext context) {
    final cubit = context.read<StatsCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SentinelaTheme.surfaceContainerHighDark,
        title: const Text('Limpar Histórico Local?'),
        content: const Text(
          'Esta ação excluirá permanentemente todos os registros de passagens e métricas de velocidade deste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SentinelaTheme.alertCritical,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              cubit.clearHistory();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('LIMPAR DADOS'),
          ),
        ],
      ),
    );
  }
}
