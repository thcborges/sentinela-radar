# Metodologia BDD/TDD & Garantia de Qualidade

A estabilidade e precisão do **Sentinela** são garantidas por uma política inegociável de desenvolvimento guiado por testes (**BDD/TDD**), auditoria de cobertura $\ge 90\%$ e varreduras automatizadas de segurança.

---

## 🎯 Meta-Regras Inquebráveis

1. **Nenhum código de produção é escrito sem teste prévio que falhe.**
2. **Cobertura Mínima de Testes:** **$\ge 90\%$** em todos os módulos e pacotes de código.
3. **Testes de Regressão Obrigatórios:** Qualquer correção de bug exige um teste prévio reproduzindo o defeito.
4. **Ordem Estrita de Execução:**
   - **Passo 1:** Execução dos testes unitários da respectiva funcionalidade.
   - **Passo 2:** Execução da suíte completa do projeto após 100% de sucesso.

---

## 📊 Cobertura Atual por Módulo

| Módulo / Pacote | Linhas Cobertas | Cobertura (%) | Status |
| :--- | :---: | :---: | :---: |
| `core/geo/` (Haversine, Bearing, Bounding Box) | 61 / 63 | **96.8%** | ✅ Aprovado |
| `core/engine/` (`AlertMachine`, `AdaptiveGpsSampler`, `AlertPreferences`) | 147 / 154 | **95.5%** | ✅ Aprovado |
| `core/platform/` (`LiveActivityService`, Dynamic Island Adapter) | 62 / 66 | **93.9%** | ✅ Aprovado |
| `core/backup/` (`BackupRestoreService` 100% Offline) | 48 / 48 | **100.0%** | ✅ Aprovado |
| `core/diagnostics/` (`SystemDiagnosticsService`) | 32 / 32 | **100.0%** | ✅ Aprovado |
| `core/audio/` (`AudioAlertPlayer`, `PlatformTtsEngine`, `ToneGenerator`, Formatter) | 83 / 84 | **98.8%** | ✅ Aprovado |
| `core/toll/` (`TollRateEstimator` e tarifas Free Flow) | 21 / 21 | **100.0%** | ✅ Aprovado |
| `core/location/` (`GeolocatorLocationService`) | 26 / 27 | **96.3%** | ✅ Aprovado |
| `core/hardware/` (`PlatformWakelockManager`) | 9 / 9 | **100.0%** | ✅ Aprovado |
| `core/network/` (`PlatformConnectivityChecker`) | 13 / 13 | **100.0%** | ✅ Aprovado |
| `core/theme/` & `models/` (Theme, POI Models, Distance Calculator) | 60 / 61 | **98.4%** | ✅ Aprovado |
| `data/database/` & `repository/` (`DatabaseManager`, `PoiRepository`, `SeedDatabaseLoader`) | 143 / 145 | **98.6%** | ✅ Aprovado |
| `data/sync/` (`PoiSyncService`, `PoiSyncParser`) | 124 / 132 | **93.9%** | ✅ Aprovado |
| `features/dashboard/` (Speedometer, Sonar, Banner, DashboardScreen, HUD Mirror) | 405 / 415 | **97.6%** | ✅ Aprovado |
| `features/overlay/` (`FloatingOverlayWidget`, `OverlayService`) | 79 / 80 | **98.8%** | ✅ Aprovado |
| `features/settings/` (`SettingsScreen`) | 176 / 184 | **95.7%** | ✅ Aprovado |
| `features/stats/` (`PassageRepository`, `StatsCubit`, `StatsScreen`, Models com Tarifas) | 221 / 224 | **98.7%** | ✅ Aprovado |
| `background/` (`BackgroundTrackingService`) | 70 / 72 | **97.2%** | ✅ Aprovado |
| `main.dart` & `overlayMain` | 68 / 72 | **94.4%** | ✅ Aprovado |
| **Total Consolidado** | **1848 / 1902 linhas** | **97.16%** | ✅ Aprovado (226 testes) |

---

## 🔒 Auditoria de Segurança com Trivy

Todas as branches e Pull Requests submetidos ao repositório disparam o analisador de vulnerabilidades de segurança e segredos **Trivy** no GitHub Actions, garantindo que dependências desatualizadas ou vulnerabilidades de segurança sejam barradas antes do merge em `develop` e `main`.
