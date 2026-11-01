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
  PoiPoint(id: 1009, latitude: -23.600100, longitude: -46.697500, type: PoiType.fixedRadar, speedLimit: 70, roadName: 'Marginal Pinheiros'),
  PoiPoint(id: 1010, latitude: -23.615000, longitude: -46.666000, type: PoiType.fixedRadar, speedLimit: 50, roadName: 'Av. dos Bandeirantes'),
  PoiPoint(id: 1011, latitude: -23.650000, longitude: -46.530000, type: PoiType.physicalSpeedBump, speedLimit: 30, roadName: 'Av. Pereira Barreto'),
  PoiPoint(id: 1012, latitude: -23.700000, longitude: -46.580000, type: PoiType.tollBooth, speedLimit: 40, roadName: 'Rod. dos Imigrantes SP-160'),
  PoiPoint(id: 1013, latitude: -23.280000, longitude: -46.880000, type: PoiType.fixedRadar, speedLimit: 100, roadName: 'Rod. dos Bandeirantes SP-348'),
  PoiPoint(id: 1014, latitude: -23.180000, longitude: -46.890000, type: PoiType.fixedRadar, speedLimit: 100, roadName: 'Rod. Anhanguera SP-330'),
  PoiPoint(id: 1015, latitude: -23.450000, longitude: -46.400000, type: PoiType.fixedRadar, speedLimit: 110, roadName: 'Rod. Ayrton Senna SP-070'),

  // Rio de Janeiro - RJ
  PoiPoint(id: 2001, latitude: -22.906847, longitude: -43.172896, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Aterro do Flamengo'),
  PoiPoint(id: 2002, latitude: -22.951916, longitude: -43.184833, type: PoiType.trafficLightRadar, speedLimit: 60, roadName: 'Praia de Botafogo'),
  PoiPoint(id: 2003, latitude: -22.860000, longitude: -43.300000, type: PoiType.fixedRadar, speedLimit: 90, roadName: 'Linha Vermelha'),
  PoiPoint(id: 2004, latitude: -22.880000, longitude: -43.120000, type: PoiType.tollBooth, speedLimit: 80, roadName: 'Ponte Rio-Niterói'),
  PoiPoint(id: 2005, latitude: -22.875000, longitude: -43.280000, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Linha Amarela'),
  PoiPoint(id: 2006, latitude: -22.830000, longitude: -43.350000, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Av. Brasil'),
  PoiPoint(id: 2007, latitude: -22.750000, longitude: -43.300000, type: PoiType.highwayPatrol, speedLimit: 90, roadName: 'Rod. Washington Luís BR-040'),
  PoiPoint(id: 2008, latitude: -22.980000, longitude: -43.200000, type: PoiType.electronicSpeedBump, speedLimit: 40, roadName: 'Av. Vieira Souto (Ipanema)'),

  // Belo Horizonte / Minas Gerais - MG
  PoiPoint(id: 3001, latitude: -19.916681, longitude: -43.934493, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Av. do Contorno'),
  PoiPoint(id: 3002, latitude: -19.850000, longitude: -43.950000, type: PoiType.physicalSpeedBump, speedLimit: 30, roadName: 'Av. Antônio Carlos'),
  PoiPoint(id: 3003, latitude: -19.880000, longitude: -43.920000, type: PoiType.trafficLightRadar, speedLimit: 60, roadName: 'Av. Cristiano Machado'),
  PoiPoint(id: 3004, latitude: -19.950000, longitude: -44.020000, type: PoiType.fixedRadar, speedLimit: 70, roadName: 'Anel Rodoviário de BH'),
  PoiPoint(id: 3005, latitude: -20.000000, longitude: -44.150000, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. Fernão Dias BR-381'),
  PoiPoint(id: 3006, latitude: -19.750000, longitude: -43.850000, type: PoiType.tollBooth, speedLimit: 40, roadName: 'Rod. MG-010 (Linha Verde)'),

  // Brasília / Distrito Federal - DF
  PoiPoint(id: 4001, latitude: -15.794229, longitude: -47.882166, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Eixo Rodoviário (Eixão)'),
  PoiPoint(id: 4002, latitude: -15.780000, longitude: -47.900000, type: PoiType.trafficLightRadar, speedLimit: 60, roadName: 'W3 Sul'),
  PoiPoint(id: 4003, latitude: -15.820000, longitude: -47.980000, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'EPTG (Estrada Parque Taguatinga)'),
  PoiPoint(id: 4004, latitude: -15.750000, longitude: -47.950000, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Estrutural DF-095'),
  PoiPoint(id: 4005, latitude: -15.850000, longitude: -48.050000, type: PoiType.electronicSpeedBump, speedLimit: 50, roadName: 'Pistão Sul (Taguatinga)'),
  PoiPoint(id: 4006, latitude: -15.950000, longitude: -48.000000, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. BR-040 DF/GO'),

  // Curitiba / Paraná - PR
  PoiPoint(id: 5001, latitude: -25.428954, longitude: -49.267137, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Linha Verde BR-476'),
  PoiPoint(id: 5002, latitude: -25.450000, longitude: -49.280000, type: PoiType.electronicSpeedBump, speedLimit: 40, roadName: 'Av. Sete de Setembro'),
  PoiPoint(id: 5003, latitude: -25.460000, longitude: -49.250000, type: PoiType.trafficLightRadar, speedLimit: 60, roadName: 'Av. Marechal Floriano Peixoto'),
  PoiPoint(id: 5004, latitude: -25.550000, longitude: -49.180000, type: PoiType.tollBooth, speedLimit: 40, roadName: 'Rod. BR-277'),
  PoiPoint(id: 5005, latitude: -25.600000, longitude: -49.200000, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. Régis Bittencourt BR-116'),

  // Porto Alegre / Rio Grande do Sul - RS
  PoiPoint(id: 6001, latitude: -30.034647, longitude: -51.217658, type: PoiType.fixedRadar, speedLimit: 70, roadName: 'Av. Ipiranga'),
  PoiPoint(id: 6002, latitude: -29.980000, longitude: -51.180000, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. Osvaldo Aranha BR-290'),
  PoiPoint(id: 6003, latitude: -30.010000, longitude: -51.150000, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Av. Sertório'),
  PoiPoint(id: 6004, latitude: -29.950000, longitude: -51.050000, type: PoiType.tollBooth, speedLimit: 40, roadName: 'Freeway BR-290'),
  PoiPoint(id: 6005, latitude: -30.060000, longitude: -51.230000, type: PoiType.physicalSpeedBump, speedLimit: 30, roadName: 'Av. Borges de Medeiros'),

  // Florianópolis / Santa Catarina - SC
  PoiPoint(id: 7001, latitude: -27.595378, longitude: -48.548050, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Av. Beira-Mar Norte'),
  PoiPoint(id: 7002, latitude: -27.600000, longitude: -48.620000, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Rod. BR-101 (São José)'),
  PoiPoint(id: 7003, latitude: -27.150000, longitude: -48.600000, type: PoiType.tollBooth, speedLimit: 40, roadName: 'Rod. BR-101 (Porto Belo)'),

  // Salvador / Bahia - BA
  PoiPoint(id: 8001, latitude: -12.971389, longitude: -38.501389, type: PoiType.fixedRadar, speedLimit: 70, roadName: 'Av. Luís Viana Filho (Paralela)'),
  PoiPoint(id: 8002, latitude: -12.980000, longitude: -38.480000, type: PoiType.trafficLightRadar, speedLimit: 60, roadName: 'Av. Antônio Carlos Magalhães'),
  PoiPoint(id: 8003, latitude: -12.900000, longitude: -38.450000, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Rod. BR-324'),
  PoiPoint(id: 8004, latitude: -12.800000, longitude: -38.300000, type: PoiType.tollBooth, speedLimit: 40, roadName: 'Estrada do Coco BA-099'),

  // Recife / Pernambuco - PE
  PoiPoint(id: 9001, latitude: -8.047562, longitude: -34.877002, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Av. Gov. Agamenon Magalhães'),
  PoiPoint(id: 9002, latitude: -8.120000, longitude: -34.900000, type: PoiType.electronicSpeedBump, speedLimit: 40, roadName: 'Av. Boa Viagem'),
  PoiPoint(id: 9003, latitude: -8.080000, longitude: -35.000000, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. BR-101 / BR-232'),

  // Fortaleza / Ceará - CE
  PoiPoint(id: 10001, latitude: -3.731862, longitude: -38.526671, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Av. Washington Soares'),
  PoiPoint(id: 10002, latitude: -3.750000, longitude: -38.560000, type: PoiType.trafficLightRadar, speedLimit: 50, roadName: 'Av. Bezerra de Menezes'),
  PoiPoint(id: 10003, latitude: -3.850000, longitude: -38.500000, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. BR-116'),

  // Goiânia / Goiás - GO
  PoiPoint(id: 11001, latitude: -16.686891, longitude: -49.264794, type: PoiType.fixedRadar, speedLimit: 60, roadName: 'Av. 85'),
  PoiPoint(id: 11002, latitude: -16.700000, longitude: -49.250000, type: PoiType.electronicSpeedBump, speedLimit: 40, roadName: 'Av. Anhanguera'),
  PoiPoint(id: 11003, latitude: -16.750000, longitude: -49.220000, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Rod. BR-153'),

  // Vitória / Vila Velha / Espírito Santo - ES
  PoiPoint(id: 12001, latitude: -20.3155, longitude: -40.3128, type: PoiType.fixedRadar, speedLimit: 80, roadName: 'Terceira Ponte'),
  PoiPoint(id: 12002, latitude: -20.3500, longitude: -40.2900, type: PoiType.trafficLightRadar, speedLimit: 60, roadName: 'Rodovia do Sol ES-060'),
  PoiPoint(id: 12003, latitude: -20.2500, longitude: -40.3800, type: PoiType.highwayPatrol, speedLimit: 80, roadName: 'Rod. BR-101'),
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
