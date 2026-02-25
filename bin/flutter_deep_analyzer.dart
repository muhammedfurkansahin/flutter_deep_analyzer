import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_deep_analyzer/flutter_deep_analyzer.dart';

/// Flutter Deep Analyzer CLI giriş noktası.
///
/// Kullanım:
///   dart run flutter_deep_analyzer analyze `path`
///   dart run flutter_deep_analyzer analyze --format=json `path`
///   dart run flutter_deep_analyzer analyze --format=html --output=report.html `path`
///   dart run flutter_deep_analyzer analyze --category=security `path`
void main(List<String> arguments) async {
  final parser = ArgParser();

  // Ana komut
  final analyzeParser = ArgParser()
    ..addOption(
      'format',
      abbr: 'f',
      help: 'Çıktı formatı',
      allowed: ['console', 'json', 'html'],
      defaultsTo: 'console',
    )
    ..addOption('output', abbr: 'o', help: 'Rapor çıktı dosyası yolu')
    ..addOption(
      'category',
      abbr: 'c',
      help: 'Sadece belirli bir kategoriyi analiz et',
      allowed: [
        'architecture',
        'code_quality',
        'best_practice',
        'security',
        'race_condition',
        'performance',
        'memory_leak',
      ],
    )
    ..addOption('config', help: 'Konfigürasyon dosyası yolu')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Yardım mesajını göster');

  parser.addCommand('analyze', analyzeParser);

  parser.addFlag('help', abbr: 'h', negatable: false, help: 'Yardım mesajını göster');

  parser.addFlag('version', abbr: 'v', negatable: false, help: 'Versiyon bilgisini göster');

  try {
    final results = parser.parse(arguments);

    if (results['version'] == true) {
      print('Flutter Deep Analyzer v0.1.0');
      exit(0);
    }

    if (results['help'] == true || results.command == null) {
      _printUsage(parser, analyzeParser);
      exit(0);
    }

    if (results.command!.name == 'analyze') {
      await _runAnalysis(results.command!, analyzeParser);
    }
  } catch (e) {
    stderr.writeln('❌ Hata: $e');
    stderr.writeln();
    _printUsage(parser, analyzeParser);
    exit(1);
  }
}

Future<void> _runAnalysis(ArgResults results, ArgParser parser) async {
  if (results['help'] == true) {
    print('Kullanım: flutter_deep_analyzer analyze [options] <path>\n');
    print(parser.usage);
    exit(0);
  }

  if (results.rest.isEmpty) {
    stderr.writeln('❌ Hata: Analiz edilecek dizin yolu belirtilmeli.');
    stderr.writeln('Kullanım: flutter_deep_analyzer analyze <path>');
    exit(1);
  }

  final targetPath = results.rest.first;
  final format = results['format'] as String;
  final outputPath = results['output'] as String?;
  final categoryFilter = results['category'] as String?;
  final configPath = results['config'] as String?;

  // Hedef dizin kontrolü
  final targetDir = Directory(targetPath);
  if (!targetDir.existsSync()) {
    stderr.writeln('❌ Hata: Dizin bulunamadı: $targetPath');
    exit(1);
  }

  // Konfigürasyon yükle
  final config = configPath != null
      ? AnalyzerConfig.fromYamlFile(configPath)
      : AnalyzerConfig.fromYamlFile(p.join(targetPath, 'analysis_options.yaml'));

  // Runner oluştur
  final runner = AnalyzerRunner(config: config);

  // Analiz başlat
  stderr.writeln('🔍 Flutter Deep Analyzer v0.1.0');
  stderr.writeln('📂 Analiz ediliyor: ${p.absolute(targetPath)}');
  stderr.writeln();

  final result = categoryFilter != null
      ? await runner.analyzeCategory(targetPath, _parseCategory(categoryFilter))
      : await runner.analyzeDirectory(targetPath);

  // Puanla
  final scorer = ProjectScorer();
  final score = scorer.score(result);

  // Raporla
  final reporter = _createReporter(format);
  final report = reporter.report(result, score);

  // Çıktı
  if (outputPath != null) {
    final outputFile = File(outputPath);
    await outputFile.writeAsString(report);
    stderr.writeln('📄 Rapor kaydedildi: $outputPath');
  } else {
    print(report);
  }

  // Hata varsa exit code 1
  if (result.errorCount > 0) {
    exit(1);
  }
}

BaseReporter _createReporter(String format) {
  switch (format) {
    case 'json':
      return JsonReporter();
    case 'html':
      return HtmlReporter();
    case 'console':
    default:
      return ConsoleReporter();
  }
}

IssueCategory _parseCategory(String name) {
  switch (name) {
    case 'architecture':
      return IssueCategory.architecture;
    case 'code_quality':
      return IssueCategory.codeQuality;
    case 'best_practice':
      return IssueCategory.bestPractice;
    case 'security':
      return IssueCategory.security;
    case 'race_condition':
      return IssueCategory.raceCondition;
    case 'performance':
      return IssueCategory.performance;
    case 'memory_leak':
      return IssueCategory.memoryLeak;
    default:
      throw ArgumentError('Bilinmeyen kategori: $name');
  }
}

void _printUsage(ArgParser parser, ArgParser analyzeParser) {
  print('''
🔍 Flutter Deep Analyzer v0.1.0
Kapsamlı Flutter ve Dart statik analiz aracı.

Kullanım:
  flutter_deep_analyzer analyze [options] <path>

Komutlar:
  analyze    Belirtilen dizini analiz et

Analyze Seçenekleri:
${analyzeParser.usage}

Örnekler:
  flutter_deep_analyzer analyze .
  flutter_deep_analyzer analyze --format=json --output=report.json .
  flutter_deep_analyzer analyze --format=html --output=report.html .
  flutter_deep_analyzer analyze --category=security .
  flutter_deep_analyzer analyze --config=custom_config.yaml .

Kategoriler:
  architecture    Mimari analizi
  code_quality    Kod kalitesi analizi
  best_practice   Best practice kontrolü
  security        Güvenlik açıkları
  race_condition  Race condition tespiti
  performance     Performans analizi
  memory_leak     Bellek sızıntısı tespiti
''');
}
