import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sentinela/core/export/dataset_exporter.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/sync/poi_sync_parser.dart';
import 'package:sentinela/domain/sync/multi_source_radar_builder.dart';
import 'package:sqlite3/sqlite3.dart';

const String kAnttPedagiosUrl =
    'https://dados.antt.gov.br/dataset/a7e1e12d-f8e8-40cd-bc1f-57973a4a4a6d/resource/d400debd-8058-4971-9625-8b614b08cf9c/download/dados-dos-praas-de-pedgio.json';

const String kAnttRadaresUrl =
    'https://dados.antt.gov.br/dataset/79d287f4-f5ca-4385-a17c-f61f53831f17/resource/81c5895f-7e59-4397-ad25-43c87d3acef5/download/dados-dos-radares10_2026.json';

const String kPrfRadaresUrl =
    'https://script.google.com/macros/s/AKfycbwnuoKDXO_3-d5hp-FSLBDRxZQhsC-WHTPIEKthAUNEDA6xsWH6EWZiE6HDz2vDZQOS2g/exec';

const String kOpenClawUfUrl =
    'https://servidor3.lucas.inf.br/openclaw/radar/api.pse?rota=/api/v1/status/estados/';

const String kPrfFallbackJson = 'assets/db/prf_radares.json';
const String kDnitFallbackJson = 'assets/db/dnit_pncv.json';

final List<String> kMajorUfs = [
  'SP',
  'RJ',
  'MG',
  'PR',
  'RS',
  'SC',
  'BA',
  'PE',
  'DF',
  'GO',
  'ES',
  'CE',
  'MT',
  'MS',
  'PA',
  'PB',
  'RN',
  'AL',
  'SE',
  'PI',
  'MA',
  'TO',
  'RO',
  'AC',
  'AP',
  'RR',
  'AM',
];

Future<void> main(List<String> args) async {
  String outputDir = 'build/datasets';
  String sourceJson = 'assets/db/sentinela_pois_brasil.json';
  bool cleanDb = false;
  String cleanTarget = 'assets/db/sentinela_brasil.db';
  bool offlineOnly = false;

  for (final arg in args) {
    if (arg.startsWith('--output-dir=')) {
      outputDir = arg.substring('--output-dir='.length);
    } else if (arg.startsWith('--source-json=')) {
      sourceJson = arg.substring('--source-json='.length);
    } else if (arg == '--clean-db') {
      cleanDb = true;
    } else if (arg.startsWith('--clean-target=')) {
      cleanTarget = arg.substring('--clean-target='.length);
    } else if (arg == '--offline-only') {
      offlineOnly = true;
    }
  }

  const exporter = DatasetExporter();

  if (cleanDb) {
    stdout.writeln(
      'Gerando base SQLite limpa (clean install): $cleanTarget...',
    );
    exporter.createCleanDatabase(targetPath: cleanTarget);
    stdout.writeln('Base limpa gerada com sucesso em: $cleanTarget');
  }

  final outDir = Directory(outputDir);
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final dbPath = '$outputDir/sentinela_brasil.db';
  final jsonPath = '$outputDir/sentinela_pois_brasil.json';
  final csvPath = '$outputDir/sentinela_pois_brasil.csv';
  final shaPath = '$outputDir/SHA256SUMS.txt';

  // Remove banco anterior se existir
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
  }

  final rawDb = sqlite3.open(dbPath);
  const builder = MultiSourceRadarBuilder();
  builder.initializeMultiSourceSchema(rawDb);

  final List<PoiPoint> allPois = [];
  final Map<String, int> sourceSummaries = {};

  final client = http.Client();
  const requestHeaders = {
    'User-Agent': 'Mozilla/5.0 SentinelaRadarPipeline/1.0',
  };

  // 1. ANTT Praças de Pedágio
  stdout.writeln('[Fonte 1/6] Coletando Praças de Pedágio ANTT...');
  List<dynamic> anttPedagiosRaw = [];
  if (!offlineOnly) {
    try {
      final resp = await client
          .get(Uri.parse(kAnttPedagiosUrl), headers: requestHeaders)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['praca-de-pedagio'] is List) {
          anttPedagiosRaw = decoded['praca-de-pedagio'] as List;
        } else if (decoded is List) {
          anttPedagiosRaw = decoded;
        }
      }
    } catch (e) {
      stdout.writeln(
        '  Aviso: Falha ao baixar dados online de pedágios ANTT ($e).',
      );
    }
  }

  final anttPedagiosPoints = builder.ingestAnttPedagios(rawDb, anttPedagiosRaw);
  allPois.addAll(anttPedagiosPoints);
  sourceSummaries['source_antt_pedagios'] = anttPedagiosPoints.length;
  stdout.writeln(
    '  -> ANTT Pedágios salvos na tabela source_antt_pedagios: ${anttPedagiosPoints.length} praças',
  );

  // 2. ANTT Radares
  stdout.writeln('[Fonte 2/6] Coletando Radares de Velocidade ANTT...');
  List<dynamic> anttRadaresRaw = [];
  if (!offlineOnly) {
    try {
      final resp = await client
          .get(Uri.parse(kAnttRadaresUrl), headers: requestHeaders)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['radar'] is List) {
          anttRadaresRaw = decoded['radar'] as List;
        } else if (decoded is List) {
          anttRadaresRaw = decoded;
        }
      }
    } catch (e) {
      stdout.writeln(
        '  Aviso: Falha ao baixar dados online de radares ANTT ($e).',
      );
    }
  }

  final anttRadaresPoints = builder.ingestAnttRadares(rawDb, anttRadaresRaw);
  allPois.addAll(anttRadaresPoints);
  sourceSummaries['source_antt_radares'] = anttRadaresPoints.length;
  stdout.writeln(
    '  -> ANTT Radares salvos na tabela source_antt_radares: ${anttRadaresPoints.length} radares',
  );

  // 3. PRF Radares Federais Oficiais
  stdout.writeln(
    '[Fonte 3/6] Coletando Radares Federais da Polícia Rodoviária Federal (PRF)...',
  );
  List<dynamic> prfRaw = [];
  if (!offlineOnly) {
    try {
      final resp = await client
          .get(Uri.parse(kPrfRadaresUrl), headers: requestHeaders)
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['records'] is List) {
          prfRaw = decoded['records'] as List;
        } else if (decoded is List) {
          prfRaw = decoded;
        }
      }
    } catch (e) {
      stdout.writeln('  Aviso: Falha ao baixar dados online da PRF ($e).');
    }
  }
  if (prfRaw.isEmpty && File(kPrfFallbackJson).existsSync()) {
    try {
      final fallbackStr = File(kPrfFallbackJson).readAsStringSync();
      final decoded = jsonDecode(fallbackStr);
      if (decoded is List) {
        prfRaw = decoded;
      } else if (decoded is Map && decoded['records'] is List) {
        prfRaw = decoded['records'] as List;
      }
      stdout.writeln('  -> Carregados dados de fallback PRF: ${prfRaw.length} registros');
    } catch (_) {}
  }
  final prfPoints = builder.ingestPrfRadares(rawDb, prfRaw);
  allPois.addAll(prfPoints);
  sourceSummaries['source_prf_radares'] = prfPoints.length;
  stdout.writeln(
    '  -> PRF Radares salvos na tabela source_prf_radares: ${prfPoints.length} radares',
  );

  // 4. DNIT PNCV Controle de Velocidade
  stdout.writeln(
    '[Fonte 4/6] Coletando Controle de Velocidade DNIT PNCV...',
  );
  List<dynamic> dnitRaw = [];
  if (File(kDnitFallbackJson).existsSync()) {
    try {
      final str = File(kDnitFallbackJson).readAsStringSync();
      final decoded = jsonDecode(str);
      if (decoded is List) {
        dnitRaw = decoded;
      }
    } catch (_) {}
  }
  final dnitPoints = builder.ingestDnitPncv(rawDb, dnitRaw);
  allPois.addAll(dnitPoints);
  sourceSummaries['source_dnit_pncv'] = dnitPoints.length;
  stdout.writeln(
    '  -> DNIT PNCV salvos na tabela source_dnit_pncv: ${dnitPoints.length} radares e redutores',
  );

  // 5. Cadastro Nacional Aberto (OpenClaw / DNIT / DERs / CETs)
  stdout.writeln(
    '[Fonte 5/6] Coletando Cadastro Nacional Aberto de Fiscalização (Paginação Completa 27 UFs)...',
  );
  List<dynamic> nacionalRaw = [];
  if (!offlineOnly) {
    for (final uf in kMajorUfs) {
      String? cursor;
      int ufCount = 0;
      while (true) {
        try {
          var url = '$kOpenClawUfUrl$uf&formato=json&limite=1000';
          if (cursor != null && cursor.isNotEmpty) {
            url += '&depois=$cursor';
          }
          final resp = await client
              .get(Uri.parse(url), headers: requestHeaders)
              .timeout(const Duration(seconds: 15));
          if (resp.statusCode == 200) {
            final decoded = jsonDecode(resp.body);
            if (decoded is Map && decoded['resultado'] is Map) {
              final res = decoded['resultado'] as Map;
              if (res['pontos'] is List) {
                final list = res['pontos'] as List;
                nacionalRaw.addAll(list);
                ufCount += list.length;
              }
              final nextCursor = res['proximo_depois']?.toString();
              if (nextCursor != null &&
                  nextCursor.isNotEmpty &&
                  nextCursor != cursor) {
                cursor = nextCursor;
              } else {
                break;
              }
            } else {
              break;
            }
          } else {
            break;
          }
        } catch (e) {
          stdout.writeln(
            '  Aviso: Falha pontual na UF $uf (cursor: $cursor): $e',
          );
          break;
        }
      }
      stdout.writeln('  -> UF $uf: $ufCount pontos coletados');
    }
  }

  final nacionalPoints = builder.ingestCadastroNacional(rawDb, nacionalRaw);
  allPois.addAll(nacionalPoints);
  sourceSummaries['source_nacional_aberto'] = nacionalPoints.length;
  stdout.writeln(
    '  -> Cadastro Nacional salvo na tabela source_nacional_aberto: ${nacionalPoints.length} pontos',
  );

  // 6. OpenStreetMap Comunitário (Fallback para snapshot/cache local)
  stdout.writeln('[Fonte 6/6] Carregando base OpenStreetMap comunitária...');
  List<PoiPoint> osmPoints = [];
  final sourceFile = File(sourceJson);
  if (sourceFile.existsSync()) {
    try {
      final jsonStr = sourceFile.readAsStringSync();
      osmPoints = PoiSyncParser.parseJsonPayload(jsonStr);
    } catch (e) {
      stderr.writeln('  Erro ao analisar JSON OSM: $e');
    }
  }

  final ingestedOsm = builder.ingestOsmComunitario(rawDb, osmPoints);
  allPois.addAll(ingestedOsm);
  sourceSummaries['source_osm_comunitario'] = ingestedOsm.length;
  stdout.writeln(
    '  -> OpenStreetMap salvo na tabela source_osm_comunitario: ${ingestedOsm.length} elementos',
  );

  client.close();

  stdout.writeln('Total bruto de pontos agregados: ${allPois.length}');

  // 5. Deduplicação Espacial Inteligente (<35m)
  stdout.writeln(
    'Executando deduplicação espacial de alta fidelidade (<35 metros)...',
  );
  final consolidatedPois = builder.deduplicatePois(
    allPois,
    distanceThresholdMeters: 35.0,
  );
  stdout.writeln(
    'Total de pontos consolidados e deduplicados: ${consolidatedPois.length}',
  );

  // 6. Salvando tabela consolidada e R*Tree index no SQLite
  stdout.writeln(
    'Consolidando tabela `pois` e índice espacial R*Tree `pois_index`...',
  );
  builder.saveConsolidatedPois(
    rawDb,
    consolidatedPois,
    sourceSummaries: sourceSummaries,
    lastUpdated: DateTime.now().toUtc(),
  );
  rawDb.close();

  // 7. Gerando JSON e CSV consolidados
  stdout.writeln('Gerando JSON consolidado: $jsonPath...');
  final jsonOut = exporter.exportToJson(consolidatedPois, pretty: true);
  File(jsonPath).writeAsStringSync(jsonOut);

  stdout.writeln('Gerando CSV tabular consolidado: $csvPath...');
  final csvOut = exporter.exportToCsv(consolidatedPois);
  File(csvPath).writeAsStringSync(csvOut);

  // 8. Calculando SHA-256
  stdout.writeln('Calculando checksums SHA-256 dos artefatos...');
  final filesToHash = [File(dbPath), File(jsonPath), File(csvPath)];

  final shaBuffer = StringBuffer();
  for (final file in filesToHash) {
    final bytes = file.readAsBytesSync();
    final digest = sha256.convert(bytes);
    final filename = file.uri.pathSegments.last;
    shaBuffer.writeln('$digest  $filename');
  }
  File(shaPath).writeAsStringSync(shaBuffer.toString());

  stdout.writeln('Artefatos gerados com sucesso no diretório $outputDir:');
  stdout.writeln(' - $dbPath (${File(dbPath).lengthSync()} bytes)');
  stdout.writeln(' - $jsonPath (${File(jsonPath).lengthSync()} bytes)');
  stdout.writeln(' - $csvPath (${File(csvPath).lengthSync()} bytes)');
  stdout.writeln(' - $shaPath');
  stdout.writeln('Pipeline multi-fonte concluído com sucesso.');
}
