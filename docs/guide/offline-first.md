# Estratégia Offline-First & SQLite R*Tree

O **Sentinela** adota uma estratégia 100% offline-first sem depender de internet nem de infraestruturas centralizadas proprietárias.

---

## 💾 O Índice Espacial R*Tree do SQLite

Para permitir buscas espaciais de altíssima frequência a cada atualização do sinal de GPS (1 a 10 Hz) sem drenar a bateria do dispositivo, utilizamos a extensão nativa **R\*Tree** do SQLite.

### Estrutura das Tabelas
```sql
-- Tabela de atributos alfanuméricos dos POIs
CREATE TABLE pois (
    id INTEGER PRIMARY KEY,
    type INTEGER NOT NULL,
    speed_limit INTEGER,
    direction INTEGER,
    tolerance_angle REAL DEFAULT 35.0,
    road_name TEXT,
    toll_fee_car REAL,
    operator TEXT,
    city TEXT,
    state TEXT,
    source TEXT
);

-- Índice virtual espacial com Bounding Box (microsegundos)
CREATE VIRTUAL TABLE pois_index USING rtree(
    id,
    min_lat, max_lat,
    min_lon, max_lon
);
```

### Consulta Espacial em Bounding Box
Para um veículo na coordenada $(\phi, \lambda)$ e um raio de busca de $1200\text{ m}$:

```sql
SELECT p.*, i.min_lat, i.min_lon
FROM pois_index i
JOIN pois p ON p.id = i.id
WHERE i.min_lat >= ? AND i.max_lat <= ?
  AND i.min_lon >= ? AND i.max_lon <= ?;
```

---

## 🔄 Troca Atômica com Staging Tables (Atomic Swap)

Para atualizações in-app da base de dados, a integridade do banco é protegida pelo padrão **Staging Swap**:

```mermaid
sequenceDiagram
    participant App as Aplicativo
    participant Staging as Tabelas Staging
    participant Ativa as Base Ativa SQLite

    App->>Staging: 1. Cria pois_staging e pois_index_staging
    App->>Staging: 2. Insere dados higienizados e deduplicados
    Note over App,Staging: Se a conexão Wi-Fi cair, as tabelas staging são descartadas.<br>A base ativa permanece 100% intacta.
    App->>Ativa: 3. Transação Atômica: Swap de tabelas
    Note over Ativa: DROP pois; DROP pois_index;<br>ALTER TABLE pois_staging RENAME TO pois;<br>ALTER TABLE pois_index_staging RENAME TO pois_index;
    App->>Ativa: 4. Atualiza db_metadata com data e total_count
```

---

## 🚀 Esteira Automatizada de Datasets no GitHub Releases

Para garantir a distribuição gratuita, rápida e independente de custos de servidores CDN caros, o Sentinela conta com uma esteira semanal automatizada no GitHub Actions (`.github/workflows/sync-radar-dataset.yml`):

1. **Agendamento Semanal:** Todo domingo às 03:00 UTC (00:00 Horário de Brasília).
2. **Compilação de Formatos:** O script `tools/export_radar_datasets.dart` compila e exporta a base em 3 formatos:
   - **`sentinela_brasil.db`**: Banco SQLite com índice espacial nativo R\*Tree.
   - **`sentinela_pois_brasil.json`**: Carga padronizada para sincronização direta in-app.
   - **`sentinela_pois_brasil.csv`**: Formato tabular aberto para interoperabilidade e auditoria externa.
   - **`SHA256SUMS.txt`**: Hashes de integridade criptográfica.
3. **Publicação Automatizada:** Os artefatos são publicados no GitHub Releases sob a tag flutuante `data-latest`.

---

## 📦 Instalação Limpa (Clean Install) & Sincronização Inicial

O aplicativo é instalado inicialmente com a **base limpa** (schema SQLite pré-criado, 0 POIs), reduzindo o footprint de download do instalador nas lojas e garantindo que o condutor sempre utilize a versão mais recente dos dados:

1. **Aviso de Instalação Inicial:** Ao abrir o aplicativo, o Dashboard exibe um banner tonal Material 3 informando que a base de radares não está instalada.
2. **Download sob Demanda:** Um simples toque no botão aciona o download da release mais recente diretamente do GitHub Releases (com fallback para raw e espelhos Overpass API).
3. **Processamento e Swap Atômico:** Os dados são validados, deduplicados e gravados localmente em staging tables, executando a troca atômica sem downtime.
4. **Ativação dos Alertas:** Com a base populada localmente, o aviso é automaticamente dispensado e todos os radares, semáforos, lombadas e pedágios passam a operar com alertas antecipados.

---

## ⏰ Notificação de Atualização Semanal (`DatasetUpdateChecker`)

O motor de atualização avalia matematicamente a disponibilidade de novos dados com base no cronograma da esteira semanal:

$$\text{Disponível} = \left( T_{\text{last\_update}} < T_{\text{latest\_release}} \right) \quad \text{onde} \quad T_{\text{latest\_release}} = \text{Domingo } 03\text{h}00\text{ UTC} + \Delta t_{\text{espera}} \; (1\text{ a } 2\text{ horas})$$

- O alerta semanal permanece visível no Dashboard até que o condutor execute a atualização.
- Após o swap atômico da base local, o alerta desaparece imediatamente.
