import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sentinela/core/export/dataset_exporter.dart';
import 'package:sentinela/data/sync/poi_sync_parser.dart';

void main(List<String> args) async {
  String outputDir = 'build/datasets';
  String sourceJson = 'assets/db/sentinela_pois_brasil.json';
  bool cleanDb = false;
  String cleanTarget = 'assets/db/sentinela_brasil.db';

  for (final arg in args) {
    if (arg.startsWith('--output-dir=')) {
      outputDir = arg.substring('--output-dir='.length);
    } else if (arg.startsWith('--source-json=')) {
      sourceJson = arg.substring('--source-json='.length);
    } else if (arg == '--clean-db') {
      cleanDb = true;
    } else if (arg.startsWith('--clean-target=')) {
      cleanTarget = arg.substring('--clean-target='.length);
    }
  }

  const exporter = DatasetExporter();

  if (cleanDb) {
    stdout.writeln('Gerando base SQLite limpa (clean install): $cleanTarget...');
    exporter.createCleanDatabase(targetPath: cleanTarget);
    stdout.writeln('Base limpa gerada com sucesso em: $cleanTarget');
  }

  final sourceFile = File(sourceJson);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Arquivo fonte não encontrado: $sourceJson');
    exit(1);
  }

  stdout.writeln('Carregando conjunto nacional de POIs a partir de: $sourceJson...');
  final jsonContent = sourceFile.readAsStringSync();
  final pois = PoiSyncParser.parseJsonPayload(jsonContent);
  stdout.writeln('Total de POIs carregados: ${pois.length}');

  final outDir = Directory(outputDir);
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final dbPath = '$outputDir/sentinela_brasil.db';
  final jsonPath = '$outputDir/sentinela_pois_brasil.json';
  final csvPath = '$outputDir/sentinela_pois_brasil.csv';
  final shaPath = '$outputDir/SHA256SUMS.txt';

  stdout.writeln('1. Compilando banco SQLite com índice R*Tree: $dbPath...');
  exporter.exportToSqliteDb(
    targetPath: dbPath,
    pois: pois,
    lastUpdated: DateTime.now().toUtc(),
  );

  stdout.writeln('2. Gerando JSON padronizado: $jsonPath...');
  final jsonOut = exporter.exportToJson(pois, pretty: true);
  File(jsonPath).writeAsStringSync(jsonOut);

  stdout.writeln('3. Gerando CSV tabular: $csvPath...');
  final csvOut = exporter.exportToCsv(pois);
  File(csvPath).writeAsStringSync(csvOut);

  stdout.writeln('4. Calculando checksums SHA-256...');
  final filesToHash = [
    File(dbPath),
    File(jsonPath),
    File(csvPath),
  ];

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
  stdout.writeln('Concluído.');
}
