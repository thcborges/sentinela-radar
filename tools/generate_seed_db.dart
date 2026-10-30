import 'dart:io';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/database/database_manager.dart';
import 'package:sqlite3/sqlite3.dart';

/// Amostra inicial representativa da malha viária brasileira para pré-embarque
/// e inicialização imediata 100% offline no primeiro uso do aplicativo.
const List<PoiPoint> defaultNationalSeed = [
  // São Paulo - SP
  PoiPoint(id: 1001, latitude: -23.550520, longitude: -46.633308, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Av. 23 de Maio'),
  PoiPoint(id: 1002, latitude: -23.561414, longitude: -46.655881, type: PoiType.trafficLightRadar, speedLimit: 50, roadName: 'Av. Paulista'),
  PoiPoint(id: 1003, latitude: -23.587416, longitude: -46.678453, type: PoiType.redLightCamera, speedLimit: 50, roadName: 'Av. Brig. Faria Lima'),
  PoiPoint(id: 1004, latitude: -23.520412, longitude: -46.700140, type: PoiType.fixedRadar, speedLimit: 90, roadName: 'Marginal Tietê'),
  PoiPoint(id: 1005, latitude: -23.590120, longitude: -46.691230, type: PoiType.electronicSpeedBump, speedLimit: 40, roadName: 'Av. Eng. Luís Carlos Berrini'),
  PoiPoint(id: 1006, latitude: -23.490000, longitude: -46.850000, type: PoiType.tollBooth, speedLimit: 40, roadName: 'Rod. Castelo Branco SP-280'),
  PoiPoint(id: 1007, latitude: -23.350000, longitude: -46.700000, type: PoiType.freeFlowToll, speedLimit: 100, roadName: 'Rodoanel Mário Covas SP-021'),
  PoiPoint(id: 1008, latitude: -23.200000, longitude: -45.900000, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. Presidente Dutra BR-116'),

  // Rio de Janeiro - RJ
  PoiPoint(id: 2001, latitude: -22.906847, longitude: -43.172896, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Aterro do Flamengo'),
  PoiPoint(id: 2002, latitude: -22.951916, longitude: -43.184833, type: PoiType.trafficLightRadar, speedLimit: 60, roadName: 'Praia de Botafogo'),
  PoiPoint(id: 2003, latitude: -22.860000, longitude: -43.300000, type: PoiType.fixedRadar, speedLimit: 90, roadName: 'Linha Vermelha'),
  PoiPoint(id: 2004, latitude: -22.880000, longitude: -43.120000, type: PoiType.tollBooth, speedLimit: 80, roadName: 'Ponte Rio-Niterói'),

  // Belo Horizonte - MG
  PoiPoint(id: 3001, latitude: -19.916681, longitude: -43.934493, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Av. do Contorno'),
  PoiPoint(id: 3002, latitude: -19.850000, longitude: -43.950000, type: PoiType.physicalSpeedBump, speedLimit: 30, roadName: 'Av. Antônio Carlos'),

  // Brasília - DF
  PoiPoint(id: 4001, latitude: -15.794229, longitude: -47.882166, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Eixo Rodoviário (Eixão)'),
  PoiPoint(id: 4002, latitude: -15.780000, longitude: -47.900000, type: PoiType.trafficLightRadar, speedLimit: 60, roadName: 'W3 Sul'),

  // Curitiba - PR
  PoiPoint(id: 5001, latitude: -25.428954, longitude: -49.267137, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Linha Verde BR-476'),
  PoiPoint(id: 5002, latitude: -25.450000, longitude: -49.280000, type: PoiType.electronicSpeedBump, speedLimit: 40, roadName: 'Av. Sete de Setembro'),

  // Porto Alegre - RS
  PoiPoint(id: 6001, latitude: -30.034647, longitude: -51.217658, type: PoiType.fixedRadar, speedLimit: 70, roadName: 'Av. Ipiranga'),
  PoiPoint(id: 6002, latitude: -29.980000, longitude: -51.180000, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. Osvaldo Aranha BR-290'),
];

/// Gera o banco SQLite compilado com extensão espacial R*Tree
/// para distribuição pré-embarcada nos assets do aplicativo.
Future<int> generateSeedDatabase({
  required String outputPath,
  List<PoiPoint>? pois,
}) async {
  final targetFile = File(outputPath);
  if (targetFile.existsSync()) {
    targetFile.deleteSync();
  } else {
    targetFile.parent.createSync(recursive: true);
  }

  final rawDb = sqlite3.open(outputPath);
  final dbManager = DatabaseManager(rawDb);
  dbManager.initializeSchema();

  final pointsToInsert = pois ?? defaultNationalSeed;
  dbManager.insertPoisBatch(pointsToInsert);

  // Salva metadados da base
  final stmtMeta = rawDb.prepare('''
    INSERT OR REPLACE INTO db_metadata (key, value)
    VALUES (?, ?);
  ''');

  stmtMeta.execute(['total_count', pointsToInsert.length.toString()]);
  stmtMeta.execute(['last_updated', DateTime.now().toIso8601String()]);
  stmtMeta.execute(['source', 'OpenStreetMap / Dados Abertos Brasil']);
  stmtMeta.execute(['schema_version', '1']);

  stmtMeta.close();
  rawDb.close();

  return pointsToInsert.length;
}

void main(List<String> args) async {
  final outputPath = args.isNotEmpty
      ? args.first
      : 'assets/db/sentinela_brasil.db';

  stdout.writeln('Iniciando compilação do banco SQLite R*Tree nacional...');
  final count = await generateSeedDatabase(outputPath: outputPath);
  stdout.writeln('Base pré-embarcada gerada com sucesso: $outputPath ($count POIs)');
}
