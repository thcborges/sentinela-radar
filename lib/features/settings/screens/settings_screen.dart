import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sentinela/core/backup/backup_restore_service.dart';
import 'package:sentinela/core/engine/alert_preferences.dart';
import 'package:sentinela/core/hardware/wakelock_manager.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/core/theme/sentinela_theme.dart';
import 'package:sentinela/data/sync/poi_sync_service.dart';
import 'package:sentinela/features/dashboard/bloc/dashboard_cubit.dart';
import 'package:sentinela/features/overlay/services/overlay_service.dart';

/// Tela de Configurações, Filtros e Atualização In-App da Base de Dados.
class SettingsScreen extends StatefulWidget {
  final PoiSyncService syncService;
  final Map<String, int> initialStats;
  final String lastUpdatedText;
  final DashboardCubit? dashboardCubit;
  final OverlayService? overlayService;
  final WakelockManager? wakelockManager;
  final BackupRestoreService? backupService;
  final AlertPreferences? initialPreferences;

  const SettingsScreen({
    super.key,
    required this.syncService,
    this.initialStats = const {},
    this.lastUpdatedText = 'Base instalada e pronta para uso',
    this.dashboardCubit,
    this.overlayService,
    this.wakelockManager,
    this.backupService,
    this.initialPreferences,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StreamSubscription<SyncProgress>? _syncSubscription;
  SyncProgress? _currentProgress;
  late Map<String, int> _stats;

  // Filtros locais
  bool _filterRadars = true;
  bool _filterTrafficLights = true;
  bool _filterSpeedBumps = true;
  bool _filterTolls = true;
  bool _filterPatrol = true;

  // Áudio
  bool _audioVoiceTts = true;
  bool _audioBeeps = true;

  // Janela Flutuante (Overlay) & Hardware
  bool _overlayActive = false;
  bool _onlyWifiSync = true;
  bool _keepScreenAwake = true;

  // Parâmetros de Alerta & Tolerâncias
  late AlertPreferences _preferences;
  double _speedToleranceKmh = 0.0;
  bool _alertOnlyIfOverSpeed = false;
  double _anticipationSeconds = 15.0;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences ?? const AlertPreferences();
    _speedToleranceKmh = _preferences.speedToleranceKmh;
    _alertOnlyIfOverSpeed = _preferences.alertOnlyIfOverSpeed;
    _anticipationSeconds = _preferences.anticipationTimeSeconds;
    _audioVoiceTts = _preferences.voiceEnabled;
    _audioBeeps = _preferences.soundEnabled;

    _stats = Map<String, int>.from(widget.initialStats);
    _overlayActive = widget.overlayService?.isOverlayOpen ?? false;
    _syncSubscription = widget.syncService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
          if (progress.stats != null) {
            _stats = Map<String, int>.from(progress.stats!);
          }
        });
      }
    });
  }

  void _updatePreferences() {
    final newPrefs = _preferences.copyWith(
      speedToleranceKmh: _speedToleranceKmh,
      alertOnlyIfOverSpeed: _alertOnlyIfOverSpeed,
      anticipationTimeSeconds: _anticipationSeconds,
      soundEnabled: _audioBeeps,
      voiceEnabled: _audioVoiceTts,
    );
    _preferences = newPrefs;
    widget.dashboardCubit?.alertMachine.updatePreferences(newPrefs);
  }

  Future<void> _exportBackup() async {
    if (widget.backupService != null) {
      await widget.backupService!.exportBackupToJson(preferences: _preferences);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup gerado com sucesso!'),
            backgroundColor: SentinelaTheme.alertNormal,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _triggerUpdate() {
    widget.syncService.startInAppUpdate(requireWifi: _onlyWifiSync);
  }

  @override
  Widget build(BuildContext context) {
    final isSyncing = _currentProgress != null &&
        (_currentProgress!.status == SyncStatus.downloading ||
            _currentProgress!.status == SyncStatus.processing ||
            _currentProgress!.status == SyncStatus.saving);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações & Dados'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Card de Atualização In-App da Base
          Card(
            color: SentinelaTheme.surfaceContainerDark,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sync_rounded, color: SentinelaTheme.alertNormal),
                      SizedBox(width: 10),
                      Text(
                        'Atualização da Base de POIs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Última atualização: ${widget.lastUpdatedText}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Métricas por Categoria
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildMetricTile('Radares', _stats['radares'] ?? 0, SentinelaTheme.alertWarning),
                      _buildMetricTile('Semáforos', _stats['semaforos'] ?? 0, const Color(0xFFFF5722)),
                      _buildMetricTile('Lombadas', _stats['lombadas'] ?? 0, const Color(0xFFFFEB3B)),
                      _buildMetricTile('Pedágios', _stats['pedagios'] ?? 0, SentinelaTheme.alertInfo),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Barra de Progresso ou Botão de Ação
                  if (isSyncing) ...[
                    Text(
                      _currentProgress?.message ?? 'Atualizando dados...',
                      style: const TextStyle(
                        fontSize: 14,
                        color: SentinelaTheme.alertNormal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _currentProgress?.progress,
                      backgroundColor: const Color(0xFF333333),
                      color: SentinelaTheme.alertNormal,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ] else ...[
                    if (_currentProgress?.message != null &&
                        _currentProgress!.message.isNotEmpty &&
                        _currentProgress!.status != SyncStatus.idle)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _currentProgress!.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: _currentProgress!.status == SyncStatus.error
                                ? SentinelaTheme.alertCritical
                                : SentinelaTheme.alertNormal,
                          ),
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Apenas sincronizar via Wi-Fi'),
                      subtitle: const Text('Evita consumo do pacote de dados móveis'),
                      value: _onlyWifiSync,
                      onChanged: isSyncing ? null : (val) => setState(() => _onlyWifiSync = val),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: SentinelaTheme.alertNormal,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _triggerUpdate,
                        icon: const Icon(Icons.cloud_download_rounded),
                        label: const Text(
                          'ATUALIZAR BASE AGORA (VIA WI-FI)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. Seção de Filtros de Alerta
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Filtros de Alerta',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            color: SentinelaTheme.surfaceContainerDark,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Radares de Velocidade'),
                  subtitle: const Text('Fixos e móveis'),
                  value: _filterRadars,
                  onChanged: (val) {
                    setState(() => _filterRadars = val);
                    widget.dashboardCubit?.togglePoiType(PoiType.fixedRadar, val);
                    widget.dashboardCubit?.togglePoiType(PoiType.mobileRadar, val);
                  },
                ),
                const Divider(height: 1, color: Color(0xFF262626)),
                SwitchListTile(
                  title: const Text('Semáforos e Câmeras'),
                  subtitle: const Text('Avanço de sinal vermelho e parada sobre faixa'),
                  value: _filterTrafficLights,
                  onChanged: (val) {
                    setState(() => _filterTrafficLights = val);
                    widget.dashboardCubit?.togglePoiType(PoiType.trafficLightRadar, val);
                    widget.dashboardCubit?.togglePoiType(PoiType.redLightCamera, val);
                  },
                ),
                const Divider(height: 1, color: Color(0xFF262626)),
                SwitchListTile(
                  title: const Text('Lombadas e Quebra-Molas'),
                  subtitle: const Text('Redutores físicos e eletrônicos'),
                  value: _filterSpeedBumps,
                  onChanged: (val) {
                    setState(() => _filterSpeedBumps = val);
                    widget.dashboardCubit?.togglePoiType(PoiType.physicalSpeedBump, val);
                    widget.dashboardCubit?.togglePoiType(PoiType.electronicSpeedBump, val);
                  },
                ),
                const Divider(height: 1, color: Color(0xFF262626)),
                SwitchListTile(
                  title: const Text('Praças de Pedágio'),
                  subtitle: const Text('Convencionais e pórticos Free Flow'),
                  value: _filterTolls,
                  onChanged: (val) {
                    setState(() => _filterTolls = val);
                    widget.dashboardCubit?.togglePoiType(PoiType.tollBooth, val);
                    widget.dashboardCubit?.togglePoiType(PoiType.freeFlowToll, val);
                  },
                ),
                const Divider(height: 1, color: Color(0xFF262626)),
                SwitchListTile(
                  title: const Text('Polícia Rodoviária'),
                  subtitle: const Text('Postos fixos da PRF e Estadual'),
                  value: _filterPatrol,
                  onChanged: (val) {
                    setState(() => _filterPatrol = val);
                    widget.dashboardCubit?.togglePoiType(PoiType.highwayPatrol, val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Seção de Preferências de Áudio
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Preferências de Áudio',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            color: SentinelaTheme.surfaceContainerDark,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Avisos por Voz (TTS Offline)'),
                  subtitle: const Text('Anúncios falados em português brasileiro'),
                  value: _audioVoiceTts,
                  onChanged: (val) => setState(() => _audioVoiceTts = val),
                ),
                const Divider(height: 1, color: Color(0xFF262626)),
                SwitchListTile(
                  title: const Text('Bipes de Proximidade (Sonar)'),
                  subtitle: const Text('Sinal sonoro com cadência progressiva'),
                  value: _audioBeeps,
                  onChanged: (val) => setState(() => _audioBeeps = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Seção Janela Flutuante (Overlay / PiP)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Modo de Operação',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            color: SentinelaTheme.surfaceContainerDark,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Janela Flutuante (Overlay)'),
                  subtitle: const Text('Sobrepor velocímetro e alertas a outros apps (Waze/Maps)'),
                  value: _overlayActive,
                  onChanged: (val) async {
                    setState(() => _overlayActive = val);
                    if (val) {
                      await widget.overlayService?.startOverlay();
                    } else {
                      await widget.overlayService?.stopOverlay();
                    }
                  },
                ),
                const Divider(height: 1, color: Color(0xFF262626)),
                SwitchListTile(
                  title: const Text('Manter Tela Ativa (Wakelock)'),
                  subtitle: const Text('Impede desligamento automático da tela no painel'),
                  value: _keepScreenAwake,
                  onChanged: (val) async {
                    setState(() => _keepScreenAwake = val);
                    if (val) {
                      await widget.wakelockManager?.enable();
                    } else {
                      await widget.wakelockManager?.disable();
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 5. Seção de Parâmetros de Alerta & Tolerâncias
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Parâmetros de Alerta & Tolerâncias',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            color: SentinelaTheme.surfaceContainerDark,
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('settings_alert_only_overspeed_switch'),
                  title: const Text('Silencioso se dentro do Limite'),
                  subtitle: const Text('Emitir avisos sonoros apenas em caso de excesso de velocidade'),
                  value: _alertOnlyIfOverSpeed,
                  onChanged: (val) {
                    setState(() => _alertOnlyIfOverSpeed = val);
                    _updatePreferences();
                  },
                ),
                const Divider(height: 1, color: Color(0xFF262626)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Margem de Tolerância: +${_speedToleranceKmh.toInt()} km/h',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        key: const Key('settings_speed_tolerance_slider'),
                        value: _speedToleranceKmh,
                        min: 0.0,
                        max: 15.0,
                        divisions: 3,
                        onChanged: (val) {
                          setState(() => _speedToleranceKmh = val);
                          _updatePreferences();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF262626)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tempo de Antecipação: ${_anticipationSeconds.toInt()} segundos',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        key: const Key('settings_anticipation_slider'),
                        value: _anticipationSeconds,
                        min: 10.0,
                        max: 25.0,
                        divisions: 3,
                        onChanged: (val) {
                          setState(() => _anticipationSeconds = val);
                          _updatePreferences();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 6. Seção de Backup & Restauração (100% Offline)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Backup & Privacidade Local',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Card(
            color: SentinelaTheme.surfaceContainerDark,
            child: Column(
              children: [
                ListTile(
                  key: const Key('settings_export_backup_button'),
                  leading: const Icon(Icons.download_rounded, color: SentinelaTheme.alertNormal),
                  title: const Text('Exportar Backup JSON'),
                  subtitle: const Text('Salva histórico e preferências localmente no aparelho'),
                  onTap: _exportBackup,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF282828), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E8E),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
