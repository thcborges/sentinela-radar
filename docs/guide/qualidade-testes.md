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
| `core/engine/` (`AlertMachine`, `AdaptiveGpsSampler`) | 105 / 109 | **96.3%** | ✅ Aprovado |
| `core/diagnostics/` (`SystemDiagnosticsService`) | 32 / 32 | **100.0%** | ✅ Aprovado |
| `core/audio/` (`AudioAlertPlayer`, `PlatformTtsEngine`, Formatter) | 56 / 57 | **98.2%** | ✅ Aprovado |
| `core/location/` (`GeolocatorLocationService`) | 26 / 27 | **96.3%** | ✅ Aprovado |
| `core/hardware/` (`PlatformWakelockManager`) | 9 / 9 | **100.0%** | ✅ Aprovado |
| `core/network/` (`PlatformConnectivityChecker`) | 13 / 13 | **100.0%** | ✅ Aprovado |
| `data/database/` & `repository/` (`DatabaseManager`, `PoiRepository`, `SeedDatabaseLoader`) | 143 / 145 | **98.6%** | ✅ Aprovado |
| `data/sync/` (`PoiSyncService`, `PoiSyncParser`) | 124 / 132 | **93.9%** | ✅ Aprovado |
| `features/dashboard/` (Speedometer, Sonar, Banner, DashboardScreen, Cubit) | 371 / 381 | **97.4%** | ✅ Aprovado |
| `features/overlay/` (`FloatingOverlayWidget`, `OverlayService`) | 79 / 80 | **98.8%** | ✅ Aprovado |
| `features/settings/` (`SettingsScreen`) | 129 / 131 | **98.5%** | ✅ Aprovado |
| `features/stats/` (`PassageRepository`, `StatsCubit`, `StatsScreen`, Models) | 196 / 205 | **95.6%** | ✅ Aprovado |
| `background/` (`BackgroundTrackingService`) | 56 / 57 | **98.2%** | ✅ Aprovado |
| `main.dart` & `overlayMain` | 61 / 65 | **93.8%** | ✅ Aprovado |
| **Total Consolidado** | **1519 / 1565 linhas** | **97.06%** | ✅ Aprovado (179 testes) |

---

## 🔒 Auditoria de Segurança com Trivy

Todas as branches e Pull Requests submetidos ao repositório disparam o analisador de vulnerabilidades de segurança e segredos **Trivy** no GitHub Actions, garantindo que dependências desatualizadas ou vulnerabilidades de segurança sejam barradas antes do merge em `develop` e `main`.
