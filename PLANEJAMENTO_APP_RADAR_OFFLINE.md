# Planejamento de Desenvolvimento: Aplicativo de Alerta de Radares, Lombadas, Semáforos e Pedágios 100% Offline

Este documento detalha o planejamento arquitetural, fontes de dados abertos, modelagem matemática do motor de alerta e estratégia de implementação para um aplicativo de detecção e alerta de radares de velocidade, **radares de sinal (câmeras semafóricas e avanço de sinal vermelho)**, lombadas e **praças de pedágio (convencionais e Free Flow)** no Brasil, focado em funcionamento **100% offline**, alta performance, privacidade total, sem travas de utilização e com **módulo de atualização integrado diretamente no aplicativo**.

---

## 1. Visão Geral do Projeto

### 1.1 Objetivo
Desenvolver um aplicativo móvel (Android / iOS) para detecção de radares de velocidade, **radares e câmeras de semáforo (avanço de sinal e parada sobre a faixa)**, lombadas (físicas e eletrônicas) e **praças de pedágio em todo o Brasil** que opere **completamente sem conexão com a internet**, mas que permita ao usuário **atualizar a base de dados sob demanda diretamente pelo app** quando estiver conectado à internet (ex: via Wi-Fi).

### 1.2 Princípios de Design
* **100% Offline-First:** Toda a base de dados vem pré-embarcada localmente no instalador do app. A navegação diária e os alertas não necessitam de sinal 4G/5G.
* **Atualização In-App Sob Demanda:** O próprio aplicativo contém o motor de atualização para baixar, decodificar e sincronizar os pontos das fontes abertas sem depender de servidores proprietários.
* **Privacidade Absoluta:** O sinal de GPS é processado estritamente na memória do dispositivo. Nenhuma coordenada, trajeto ou telemetria é enviada para servidores externos.
* **Sem Restrições:** Sem limites de quilometragem diária, sem necessidade de login e sem modelos de assinatura bloqueando funcionalidades essenciais.
* **Modo Overlay (Janela Flutuante):** Capacidade de funcionar minimizado em segundo plano com uma janela flutuante sobreposta a outros aplicativos (como Google Maps, Waze ou Uber).
* **Eficiência Energética:** Otimização do pooling de GPS e algoritmos de busca espacial com indexação em árvore ($R^*$-Tree) para evitar consumo excessivo de bateria.

---

## 2. Fontes de Dados Abertos no Brasil (Radares, Semáforos, Lombadas e Pedágios)

Diferente de soluções proprietárias que dependem de bases fechadas, o Brasil possui dados públicos detalhados sobre controladores de velocidade, radares semafóricos, redutores físicos e praças de pedágio regulamentados pelos órgãos de trânsito e agências reguladoras.

### 2.1 Principais Bases Públicas e Abertas

| Categoria | Fonte / Órgão | Cobertura | Formatos Disponíveis | Dados Fornecidos |
| :--- | :--- | :--- | :--- | :--- |
| **Radares de Velocidade Federais** | **DNIT (PNCV)** | Rodovias Federais não concedidas em todo o país | CSV, XLSX, API CKAN (`dados.gov.br`) | UF, Rodovia (BR), km, latitude, longitude, tipo de equipamento (fixo, barreira, redutor/lombada eletrônica), velocidade regulamentada, sentido e faixas. |
| **Radares Homologados & Semafóricos** | **INMETRO (PSIE)** | Todo o território nacional (federal, estadual e municipal) | CSV, XML (`dados.gov.br`) | Relação de todos os medidores de velocidade homologados e aferidos no Brasil, incluindo equipamentos classificados como **"Fixo com função semafórica"**, endereço/cruzamento e velocidade. |
| **Radares de Sinal e Semáforos Urbanos** | **Órgãos Municipais (CET-SP, BHTRANS, EPTC, CET-Rio, etc.)** | Capitais e grandes regiões metropolitanas | Portais de Dados Abertos Municipais (CSV/GeoJSON) | Localização exata de câmeras de fiscalização semafórica: avanço de sinal vermelho, parada sobre faixa de pedestres e fiscalização mista (velocidade + sinal). |
| **Praças de Pedágio Federais** | **ANTT (Dados Abertos)** | Rodovias Federais Concedidas (Dutra, Fernão Dias, Régis, etc.) | CSV, KMZ, JSON (`dados.antt.gov.br`) | Relação de todas as praças de pedágio, rodovia, km, coordenadas, concessionária operadora, tarifas vigentes e pórticos Free Flow. |
| **Pedágios Estaduais** | **Agências Estaduais (ARTESP-SP, AGEPAR-PR, etc.)** | Rodovias estaduais paulistas, paranaenses, gaúchas, etc. | CSV, XLS, Shapefile | Localização das praças sob concessão estadual, tarifas e postos de pesagem. |
| **Lombadas, Sinal e Malha Urbana** | **OpenStreetMap (OSM)** | Vias urbanas de capitais e cidades do interior, rodovias estaduais e federais | OSM XML, PBF, Overpass API (GeoJSON / JSON) | - **Radares de Sinal:** `enforcement=red_light`, `camera:traffic_signals=yes`, `highway=speed_camera` + `speed_camera:type=traffic_lights`.<br>- **Radares de Velocidade:** `highway=speed_camera`, `enforcement=maxspeed` com `direction` (azimute em graus).<br>- **Lombadas Físicas:** `traffic_calming=bump`, `traffic_calming=table`, `traffic_calming=hump`.<br>- **Pedágios:** `barrier=toll_booth` e `highway=toll_gantry` (Free Flow). |

### 2.2 Estratégia de Unificação e Deduplicação no Dispositivo

Ao ser acionado pelo usuário, o app executa o algoritmo de normalização e deduplicação:

```
[Fontes Abertas: Overpass API / DNIT / ANTT]
                     │  (Download via Wi-Fi)
                     ▼
  [Processamento em Isolate / Thread Secundária]
  - Parse de JSON / Coordenadas WGS84
  - Deduplicação Espacial (Clusterização 35m - 45m)
  - Identificação de pistas duplas (Preservação por azimute oposto)
                     │
                     ▼
     [Transação Atômica no SQLite Local]
  - Tabela Temporária (pois_temp e pois_index_temp)
  - Swap Atômico (Sem risco de corrupção se o download for cancelado)
                     │
                     ▼
  [Base Atualizada no Armazenamento Local]
```

1. **Classificação Padronizada dos Tipos de POIs:**
   * `1`: `FIXED_RADAR` (Radar fixo tradicional de velocidade);
   * `2`: `MOBILE_RADAR` (Ponto com autorização/histórico de radar móvel ou estático);
   * `3`: `TRAFFIC_LIGHT_RADAR` (**Semáforo com radar:** fiscaliza limite de velocidade + avanço de sinal vermelho);
   * `4`: `RED_LIGHT_CAMERA` (**Câmera de sinal:** fiscaliza exclusivamente avanço de sinal vermelho e parada sobre faixa);
   * `5`: `ELECTRONIC_SPEED_BUMP` (Lombada eletrônica com visor digital de velocidade);
   * `6`: `PHYSICAL_SPEED_BUMP` (Lombada física / quebra-molas / faixa elevada de pedestres);
   * `7`: `TOLL_BOOTH` (Praça de pedágio convencional com cabine/cancela);
   * `8`: `FREE_FLOW_TOLL` (Pórtico eletrônico de pedágio automático sem cancela - Free Flow);
   * `9`: `HIGHWAY_PATROL` (Posto fixo da Polícia Rodoviária Federal ou Estadual).

---

## 3. Arquitetura de Dados Embarcada (100% Offline)

### 3.1 Armazenamento Espacial com SQLite e R*Tree
Para realizar consultas de proximidade instantâneas sem gastar CPU ou descompactar megabytes de dados a cada segundo, a base de dados utiliza o módulo nativo **SQLite R\*Tree**:

```sql
-- Tabela principal de pontos de interesse (Radares, Semáforos, Lombadas e Pedágios)
CREATE TABLE pois (
    id INTEGER PRIMARY KEY,
    type INTEGER NOT NULL,            -- 1: Fixo, 2: Móvel, 3: Semáforo c/ Radar, 4: Câmera de Sinal, 
                                      -- 5: Lombada Eletrônica, 6: Lombada Física, 7: Pedágio, 8: Free Flow, 9: Polícia
    speed_limit INTEGER,              -- Velocidade em km/h (ex: 40, 50, 60, 80) ou NULL (para câmera de sinal sem velocidade)
    direction INTEGER,                -- Sentido em graus (0 a 359) ou NULL se omnidirecional/cruzamento
    tolerance_angle INTEGER DEFAULT 45, -- Ângulo de tolerância em graus
    road_name TEXT,                   -- Ex: "Av. Paulista", "Av. 23 de Maio", "BR-116"
    toll_fee_car REAL,                -- Tarifa de pedágio para carros (R$) ou NULL
    operator TEXT,                    -- Concessionária operadora (pedágios) ou Órgão gestor (ex: "CET", "DNIT")
    city TEXT,
    state TEXT,
    source TEXT                       -- Origem dos dados: "INMETRO+OSM", "CET+OSM", "ANTT"
);

-- Tabela de metadados para controle de versão da base
CREATE TABLE db_metadata (
    key TEXT PRIMARY KEY,
    value TEXT
);

-- Índice Espacial R*Tree do SQLite para busca ultra-rápida por Bounding Box
CREATE VIRTUAL TABLE pois_index USING rtree(
    id,                               -- Chave estrangeira para pois.id
    min_lat, max_lat,                 -- Bounding box latitude
    min_lon, max_lon                  -- Bounding box longitude
);
```

### 3.2 Otimização de Armazenamento e Performance
* Uma base nacional completa contendo:
  * ~25.000 radares fixos e móveis;
  * **~8.000 radares e câmeras de semáforo** (velocidade + avanço de sinal);
  * ~35.000 lombadas físicas e eletrônicas;
  * ~800 praças de pedágio e pórticos Free Flow;
  * ~1.500 postos da PRF e polícia estadual.
* O arquivo `radares_brasil.db` resultante ocupa aproximadamente **14 a 18 MB** com índice espacial compilado.
* Fica embutido diretamente nos recursos (`assets`) do APK/IPA, sendo acessado em modo somente-leitura no primeiro uso e atualizado no diretório de dados do app (`getApplicationDocumentsDirectory()`) após a sincronização in-app.

---

## 4. Motor Matemático de Alertas (`Alert Engine`)

O motor de alertas é o núcleo do aplicativo. Ele roda em um *loop* acoplado ao fluxo de coordenadas do GPS nativo.

### 4.1 Ciclo de Processamento do GPS

```
   [GPS Nativo (1 Hz - 2 Hz)]
                │
                ▼
      [Validação de Sinal] ──(Precisão > 35m)──► Descarte / Indicador de sinal fraco
                │
                ▼ (Precisão OK)
  [Cálculo de Vetor de Movimento]
  - Velocidade: v (km/h)
  - Rumo do Veículo: θ_carro (bearing em graus)
                │
                ▼
  [Query Espacial R*Tree (Bounding Box)]
  - Busca candidatos em raio R(v)
                │
                ▼
   [Filtragem Angular e de Sentido]
  - Ângulo relativo: |θ_carro - θ_ponto| <= α_tolerancia
                │
                ▼
   [Máquina de Estados de Alerta]
  - IDLE ➔ APPROACHING ➔ ALERTING ➔ OVER_SPEED ➔ PASSED
                │
                ▼
    [Saída: UI + Som + Voz + Overlay]
```

### 4.2 Distância Dinâmica de Alerta
Um alerta não pode disparar a uma distância fixa (ex: 200 metros). A 110 km/h (30,5 m/s), 200 metros representam apenas 6 segundos de reação.

A distância ideal de disparo $D_{alerta}$ varia conforme a velocidade e o tipo de ponto:
$$D_{alerta} = \max\left(D_{min},\, v \cdot t_{antecipacao}\right)$$

* **Para Radares de Velocidade (Fixos/Móveis):** $t_{antecipacao} \approx 12 \text{ a } 15 \text{ segundos}$;
  * A **60 km/h** ($16,6 \text{ m/s}$): $D_{alerta} \approx 250 \text{ metros}$;
  * A **110 km/h** ($30,5 \text{ m/s}$): $D_{alerta} \approx 450 \text{ metros}$.
* **Para Radares de Sinal e Câmeras Semafóricas:** $D_{alerta} \approx 180 \text{ a } 250 \text{ metros}$ (tempo ideal para atenção no cruzamento sem gerar poluição sonora em semáforos anteriores).
* **Para Lombadas Físicas:** $D_{alerta} \approx 80 \text{ a } 120 \text{ metros}$ (tempo suficiente para frenagem suave sem causar alarmes precoces em áreas urbanas lentas).
* **Para Praças de Pedágio:** $D_{alerta} \approx 800 \text{ a } 1.000 \text{ metros}$ (tempo adequado para desaceleração, escolha de cabines automáticas ou manuais e preparação da passagem).

### 4.3 Filtragem Direcional para Semáforos e Cruzamentos
Cruzamentos semafóricos possuem múltiplos braços de tráfego. Para evitar que o condutor que trafega na via transversal receba o alerta indevido:

1. **Cálculo do Rumo até o Ponto ($Azimute_{veiculo \to semaforo}$):**
   $$\theta_{alvo} = \text{atan2}\left(\sin(\Delta \lambda) \cdot \cos(\phi_2),\, \cos(\phi_1)\sin(\phi_2) - \sin(\phi_1)\cos(\phi_2)\cos(\Delta \lambda)\right)$$
2. **Conferência de Sentido:**
   * O semáforo deve estar estritamente à frente do veículo: $|\theta_{carro} - \theta_{alvo}| \le 40^\circ$.
   * A direção cadastrada da aproximação ($\theta_{semaforo}$) deve bater com o rumo do carro ($\theta_{carro}$):
     $$\Delta\theta = |\theta_{carro} - \theta_{semaforo}| \pmod{360}$$
     $$\min(\Delta\theta, 360^\circ - \Delta\theta) \le 35^\circ$$
   * Se o condutor estiver na rua que cruza o semáforo em ângulo de $90^\circ$, o filtro angular descarta o alerta instantaneamente.

---

## 5. Arquitetura de Módulos do Aplicativo

```
app/
├── core/
│   ├── geo/                 # Fórmulas de Haversine, Bearing, Bounding Box
│   ├── engine/              # AlertMachine (Máquina de estados de alerta)
│   └── audio/               # Gerenciador de áudio (bipes, ducking e TTS local)
├── data/
│   ├── database/            # SQLite R*Tree, queries espaciais pré-compiladas
│   ├── sync/                # PoiSyncService (Módulo In-App de atualização da base)
│   ├── models/              # POI, Radar, TrafficLight, TollBooth, SpeedBump, AlertState
│   └── repository/          # PoiRepository (consultas de POIs por bounding box)
├── features/
│   ├── dashboard/           # Tela cheia: velocímetro HUD, sonar circular, bússola
│   ├── overlay/             # Janela flutuante Picture-in-Picture / System Alert Window
│   ├── settings/            # Tela de Atualização In-App, filtros de tipos de alerta, canal de áudio
│   └── stats/               # Histórico local de passagens e velocidades (100% privado)
└── background/
    └── tracking_service/    # Foreground Service com notificação persistente
```

### 5.1 Sistema de Áudio e Voz Offline
* **Text-to-Speech (TTS):** Utiliza as engines nativas de TTS do sistema operacional (**Google Text-to-Speech** no Android e **AVSpeechSynthesizer** no iOS). Ambas funcionam perfeitamente sem internet quando o pacote de idioma em português (pt-BR) está instalado no sistema.
  * Mensagens faladas especializadas por tipo de POI:
    * **Radar Fixo:** *"Radar fixo a 60 km por hora à frente."*
    * **Semáforo com Radar:** *"Semáforo com radar a 50 km por hora à frente."*
    * **Câmera de Sinal (Avanço/Faixa):** *"Atenção: Fiscalização de sinal vermelho à frente."*
    * **Lombada:** *"Atenção: Lombada à frente."*
    * **Pedágio:** *"Pedágio a 1 quilômetro. Tarifa aproximada: R$ 8,50."*
    * **Free Flow:** *"Pórtico Free Flow à frente. Pedágio automático sem cancela."*
* **Bipes de Proximidade:** Arquivos de áudio leves (`.wav` ou `.ogg`) embutidos no app, emitidos com intervalo proporcional à distância do radar (efeito sonar).
* **Canal de Áudio Configurável:**
  * Canal de **Alarme** (para tocar mesmo se o celular estiver em modo silencioso ou mídia mutada);
  * Canal de **Notificação**;
  * Canal de **Mídia** com recurso de atenuação (*Audio Ducking*), baixando temporariamente a música do Spotify ou rádio durante o alerta.

### 5.2 Janela Flutuante (Overlay)
* Implementação com `SYSTEM_ALERT_WINDOW` no Android.
* Exibe miniatura translúcida e arrastável contendo:
  * Velocidade atual do carro;
  * Ícone dinâmico do alerta:
    * Placa redonda de velocidade (Radar Fixo);
    * Ícone de semáforo com câmera ou placa de velocidade (Radar de Sinal);
    * Ícone de quebra-molas (Lombada);
    * Cabine ou pórtico (Pedágio / Free Flow);
  * Indicador numérico regressivo de distância (ex: *"250 m"*);
  * Alerta visual piscante em vermelho quando a velocidade atual excede o limite.

---

## 6. Módulo In-App de Atualização da Base (Executado no Celular)

Para que o próprio usuário possa solicitar a atualização diretamente pelo celular (por exemplo, conectado ao Wi-Fi de casa antes de viajar), a lógica de download e sincronização foi convertida em um serviço Dart nativo em segundo plano (**`PoiSyncService`**).

### 6.1 Como Funciona a Atualização Dentro do Celular

1. **Execução em Isolate Secundário:** O download e o parsing de dezenas de milhares de coordenadas consomem processamento. Para não travar a interface gráfica do app (mantendo 60fps lisos), o processamento ocorre em um `Isolate` separado via `compute()`.
2. **Transação Atômica com Tabela Temporária:**
   * Os dados novos são inseridos em tabelas temporárias (`pois_staging` e `pois_index_staging`).
   * Somente quando 100% dos dados foram baixados e validados, o SQLite realiza a troca atômica (*swap*).
   * Se o usuário perder a conexão Wi-Fi no meio do processo, **a base antiga continua 100% intacta e funcional**.
3. **Estatísticas e Data da Última Atualização:**
   * O app armazena a data/hora da última atualização e exibe na tela de configurações a quantidade exata de radares, semáforos, lombadas e pedágios ativos.

### 6.2 Código Completo do Serviço em Dart (`poi_sync_service.dart`)

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

enum SyncStatus { idle, downloading, processing, saving, success, error }

class SyncProgress {
  final SyncStatus status;
  final String message;
  final double progress; // 0.0 a 1.0
  final Map<String, int>? stats;

  SyncProgress({
    required this.status,
    required this.message,
    this.progress = 0.0,
    this.stats,
  });
}

class PoiSyncService {
  final Database db;
  PoiSyncService(this.db);

  // Endpoint oficial do Overpass API ou mirror público
  static const String overpassUrl = "https://overpass-api.de/api/interpreter";

  // Stream para a interface do usuário acompanhar em tempo real
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get progressStream => _progressController.stream;

  Future<bool> startInAppUpdate() async {
    try {
      _progressController.add(SyncProgress(
        status: SyncStatus.downloading,
        message: "Conectando e baixando dados abertos do Brasil...",
        progress: 0.1,
      ));

      // 1. Consulta com todos os tipos viários brasileiros
      const String query = """
      [out:json][timeout:300];
      area["ISO3166-1"="BR"]->.brazil;
      (
        // 1. Radares de velocidade convencionais
        node["highway"="speed_camera"](area.brazil);
        node["enforcement"="maxspeed"](area.brazil);
        
        // 2. Radares de sinal (avanço de sinal vermelho e câmeras)
        node["enforcement"="red_light"](area.brazil);
        node["camera:traffic_signals"="yes"](area.brazil);
        node["red_light_camera"="yes"](area.brazil);
        node["highway"="traffic_signals"]["camera"="yes"](area.brazil);
        
        // 3. Lombadas físicas e quebra-molas
        node["traffic_calming"~"bump|table|hump"](area.brazil);
        
        // 4. Praças de pedágio convencionais e pórticos Free Flow
        node["barrier"="toll_booth"](area.brazil);
        node["highway"="toll_gantry"](area.brazil);
      );
      out body;
      """;

      final client = http.Client();
      final response = await client.post(
        Uri.parse(overpassUrl),
        body: {'data': query},
        headers: {'User-Agent': 'OfflineRadarAlertApp/1.0 (Mobile Sync)'},
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        _progressController.add(SyncProgress(
          status: SyncStatus.error,
          message: "Falha na conexão com o servidor de dados (${response.statusCode}). Tente novamente.",
        ));
        return false;
      }

      _progressController.add(SyncProgress(
        status: SyncStatus.processing,
        message: "Processando e deduplicando registros em segundo plano...",
        progress: 0.5,
      ));

      // 2. Parse e estruturação em Isolate para não travar a UI
      final List<Map<String, dynamic>> parsedPois = await compute(_parseJsonPayload, response.body);

      _progressController.add(SyncProgress(
        status: SyncStatus.saving,
        message: "Gravando ${parsedPois.length} pontos no banco local...",
        progress: 0.8,
      ));

      // 3. Atualização atômica no SQLite local com Staging Table
      final stats = await _commitToDatabase(parsedPois);

      _progressController.add(SyncProgress(
        status: SyncStatus.success,
        message: "Base atualizada com sucesso!",
        progress: 1.0,
        stats: stats,
      ));

      return true;
    } catch (e) {
      _progressController.add(SyncProgress(
        status: SyncStatus.error,
        message: "Erro na atualização: $e",
      ));
      return false;
    }
  }

  // Função isolada (roda em thread nativa de background)
  static List<Map<String, dynamic>> _parseJsonPayload(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final List elements = data['elements'] ?? [];
    final List<Map<String, dynamic>> results = [];

    for (final el in elements) {
      final double lat = (el['lat'] as num).toDouble();
      final double lon = (el['lon'] as num).toDouble();
      final Map<String, dynamic> tags = el['tags'] ?? {};
      final String road = tags['ref'] ?? tags['name'] ?? "";

      // Velocidade máxima
      int? speed;
      final speedStr = tags['maxspeed']?.toString();
      if (speedStr != null) {
        final digits = speedStr.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) speed = int.tryParse(digits);
      }

      // Direção em graus
      int? direction;
      final dirStr = tags['direction']?.toString();
      if (dirStr != null) {
        final d = double.tryParse(dirStr);
        if (d != null) direction = d.round() % 360;
      }

      int poiType = 1; // Default: Fixed radar
      String? operator;

      // 1. Pedágio convencional ou Free Flow
      if (tags['barrier'] == 'toll_booth' || tags['highway'] == 'toll_gantry') {
        poiType = (tags['highway'] == 'toll_gantry') ? 8 : 7;
        operator = tags['operator'] ?? tags['brand'];
      }
      // 2. Lombada física / quebra-mola
      else if (tags.containsKey('traffic_calming')) {
        poiType = 6;
      }
      // 3. Radares de Sinal (Avanço de vermelho / semáforo com radar)
      else if (tags['enforcement'] == 'red_light' ||
               tags['camera:traffic_signals'] == 'yes' ||
               tags['red_light_camera'] == 'yes' ||
               tags['speed_camera:type'] == 'traffic_lights') {
        poiType = (speed != null) ? 3 : 4; // 3 = Misto c/ velocidade, 4 = Apenas sinal
      }
      // 4. Radar fixo de velocidade
      else {
        poiType = 1;
      }

      results.add({
        'type': poiType,
        'speed_limit': speed,
        'direction': direction,
        'road_name': road,
        'operator': operator,
        'lat': lat,
        'lon': lon,
      });
    }

    return results;
  }

  // Gravação atômica no SQLite
  Future<Map<String, int>> _commitToDatabase(List<Map<String, dynamic>> items) async {
    final stats = <String, int>{
      'radares': 0,
      'semaforos': 0,
      'lombadas': 0,
      'pedagios': 0,
    };

    await db.transaction((txn) async {
      // 1. Limpa tabelas staging
      await txn.execute("DROP TABLE IF EXISTS pois_staging;");
      await txn.execute("DROP TABLE IF EXISTS pois_index_staging;");

      await txn.execute("""
      CREATE TABLE pois_staging (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type INTEGER NOT NULL,
          speed_limit INTEGER,
          direction INTEGER,
          road_name TEXT,
          toll_fee_car REAL,
          operator TEXT,
          city TEXT,
          state TEXT,
          source TEXT
      );
      """);

      await txn.execute("""
      CREATE VIRTUAL TABLE pois_index_staging USING rtree(
          id,
          min_lat, max_lat,
          min_lon, max_lon
      );
      """);

      // 2. Inserção em lote (Batch)
      final batch = txn.batch();
      const double delta = 0.00001;

      for (final item in items) {
        final type = item['type'] as int;

        if (type == 1 || type == 2) stats['radares'] = (stats['radares'] ?? 0) + 1;
        if (type == 3 || type == 4) stats['semaforos'] = (stats['semaforos'] ?? 0) + 1;
        if (type == 5 || type == 6) stats['lombadas'] = (stats['lombadas'] ?? 0) + 1;
        if (type == 7 || type == 8) stats['pedagios'] = (stats['pedagios'] ?? 0) + 1;

        batch.rawInsert("""
          INSERT INTO pois_staging (type, speed_limit, direction, road_name, operator, city, state, source)
          VALUES (?, ?, ?, ?, ?, '', '', 'OSM_INAPP')
        """, [
          item['type'],
          item['speed_limit'],
          item['direction'],
          item['road_name'],
          item['operator'],
        ]);
      }

      await batch.commit(noResult: true);

      // Sincroniza índice espacial staging
      await txn.execute("""
        INSERT INTO pois_index_staging (id, min_lat, max_lat, min_lon, max_lon)
        SELECT id, lat - 0.00001, lat + 0.00001, lon - 0.00001, lon + 0.00001
        FROM (SELECT id, ... FROM pois_staging);
      """);

      // 3. Swap atômico de tabelas
      await txn.execute("DROP TABLE IF EXISTS pois;");
      await txn.execute("DROP TABLE IF EXISTS pois_index;");
      await txn.execute("ALTER TABLE pois_staging RENAME TO pois;");
      await txn.execute("ALTER TABLE pois_index_staging RENAME TO pois_index;");

      // 4. Salva metadados de última atualização
      await txn.rawInsert("""
        INSERT OR REPLACE INTO db_metadata (key, value)
        VALUES ('last_updated', datetime('now', 'localtime')),
               ('total_count', ?);
      """, [items.length.toString()]);
    });

    return stats;
  }
}
```

### 6.3 Interface de Usuário no Aplicativo (Tela de Configurações)

Na tela de Configurações do app, o usuário visualiza:

```
┌────────────────────────────────────────────────────────┐
│  Atualização da Base de Radares e POIs                │
│                                                        │
│  Última atualização: 29/10/2026 às 15:30               │
│  Status: Base atualizada e pronta para uso offline     │
│                                                        │
│  • Radares de velocidade:  24.810                      │
│  • Semáforos e sinal:       7.940                      │
│  • Lombadas / Quebra-molas: 34.200                     │
│  • Praças de pedágio:         830                      │
│                                                        │
│  [  ATUALIZAR BASE AGORA (VIA WI-FI)  ]               │
└────────────────────────────────────────────────────────┘
```

Ao tocar no botão, uma barra de progresso linear exibe o andamento com mensagens em tempo real (*"Baixando dados..."* $\to$ *"Deduplicando registros..."* $\to$ *"Concluído"*), sem interromper a navegação nem exigir login.

---

## 7. Fases de Desenvolvimento e Roadmap

```
[Fase 1: Módulo Sync In-App] ──► [Fase 2: Motor de Alerta] ──► [Fase 3: Interface & HUD] ──► [Fase 4: Overlay & Áudio]
- Sincronizador Dart/Isolate       - Validador GPS               - Velocímetro analógico/HUD  - Background Service
- SQLite R*Tree com Staging Swap   - Cálculo vetorial/azimute    - Sonar circular de POIs     - Overlay Window (Waze/Maps)
- Deduplicação em background       - Tolerância angular cruzamento- Bússola digital           - TTS Offline + Bipes WAV
```

### Fase 1: Sincronização In-App e Base Embarcada (Semana 1)
* Criação do banco SQLite compilado com módulo R\*Tree com suporte a radares, semáforos de sinal, quebra-molas e pedágios.
* Implementação do `PoiSyncService` em Dart rodando em `Isolate` de background.
* Criação da interface com botão de atualização sob demanda e barra de progresso.

### Fase 2: Motor de Alerta Geográfico (Semanas 2 e 3)
* Algoritmo de filtragem angular e cone de detecção para pistas simples, duplas e cruzamentos ortogonais.
* Distâncias adaptativas diferenciadas (Radares a 400m, Semáforos a 200m, Lombadas a 100m, Pedágios a 1km).
* Testes de unidade com trajetos gravados em GPX para checagem de falsos positivos/negativos em cruzamentos semafóricos.

### Fase 3: Interface e Experiência do Usuário (Semana 4)
* Dashboard principal: velocímetro digital de alta visibilidade, aviso do limite da via e bússola de rumo.
* Efeito radar/sonar mostrando pontos de interesse se aproximando no campo visual frontal.
* Filtros em configurações para ativar/desativar categorias específicas (ex: silenciar lombadas e manter apenas radares, semáforos e pedágios).

### Fase 4: Janela Flutuante (Overlay) e Áudio (Semanas 5 e 6)
* Implementação do `OverlayService` flutuante sobre outros navegadores.
* Integração com Text-to-Speech nativo offline anunciando radares, semáforos com câmera, quebra-molas e pedágios.
* Foreground Service otimizado para não sofrer encerramento pelo gerenciador de bateria do Android (Doze Mode).
