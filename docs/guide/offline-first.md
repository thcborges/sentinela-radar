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
