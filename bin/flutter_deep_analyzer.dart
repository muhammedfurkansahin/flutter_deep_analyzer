import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_deep_analyzer/flutter_deep_analyzer.dart';

/// Flutter Deep Analyzer CLI giriş noktası.
///
/// Kullanım:
///   dart run flutter_deep_analyzer analyze --format=json `path`
///   dart run flutter_deep_analyzer analyze --format=html --output=report.html `path`
///   dart run flutter_deep_analyzer analyze --format=markdown --output=report.md `path`
///   dart run flutter_deep_analyzer analyze --category=security `path`
void main(List<String> arguments) async {
  final parser = ArgParser();

  // Ana komut
  final analyzeParser = ArgParser()
    ..addOption(
      'format',
      abbr: 'f',
      help: 'Çıktı formatı',
      allowed: ['console', 'json', 'html', 'markdown', 'sonarqube'],
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
        'type_safety',
      ],
    )
    ..addOption('config', help: 'Konfigürasyon dosyası yolu')
    ..addFlag('create-baseline',
        help: 'Mevcut hataları baseline.json dosyasına kaydeder ve yoksayar', negatable: false)
    ..addOption('use-baseline',
        help: 'Belirtilen baseline dosyasındaki hataları analizden hariç tutar')
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

  String format = results['format'] as String;
  String? outputPath = results['output'] as String?;
  String? categoryFilter = results['category'] as String?;
  String? configPath = results['config'] as String?;
  String language =
      'tr'; // Default language fallback for interactive prompt, can be implemented further

  try {
    if (results.options.contains('language')) {
      language = results['language'] as String? ?? 'tr';
    }
  } catch (_) {}

  String targetPath;
  bool createBaseline = results['create-baseline'] == true;
  String? useBaselinePath = results['use-baseline'] as String?;

  // İnteraktif mod tetikleyici: Argüman yollanmamışsa
  if (results.rest.isEmpty && !results.wasParsed('format') && !results.wasParsed('category')) {
    stdout.write('🌍 Lütfen dil seçin / Please select language (tr/en) [tr]: ');
    final langInput = stdin.readLineSync()?.trim().toLowerCase();
    if (langInput == 'en') language = 'en';

    final promptTextCat = language == 'en'
        ? '📂 Category Selection: Select category (all, architecture, code_quality, best_practice, security, race_condition, performance, memory_leak, type_safety) [all]: '
        : '📂 Kategori Seçimi: Kategori seçin (all, architecture, code_quality, best_practice, security, race_condition, performance, memory_leak, type_safety) [all]: ';
    stdout.write(promptTextCat);
    final catInput = stdin.readLineSync()?.trim();
    if (catInput != null && catInput.isNotEmpty && catInput != 'all') {
      categoryFilter = catInput;
    }

    final promptTextFormat = language == 'en'
        ? '📄 Report Format: Select report format (console, json, html, markdown, sonarqube) [console]: '
        : '📄 Rapor Formatı: Rapor formatı seçin (console, json, html, markdown, sonarqube) [console]: ';
    stdout.write(promptTextFormat);
    final formatInput = stdin.readLineSync()?.trim();
    if (formatInput != null && formatInput.isNotEmpty) {
      format = formatInput;
    }

    final promptTargetPath = language == 'en'
        ? '📁 Project Directory: Enter project path (Leave empty for current directory): '
        : '📁 Proje Dizini: Proje dizinini girin (Mevcut dizin için boş bırakın): ';
    stdout.write(promptTargetPath);
    final pathInput = stdin.readLineSync()?.trim();
    if (pathInput != null && pathInput.isNotEmpty && pathInput != '.') {
      targetPath = pathInput;
    } else {
      targetPath = Directory.current.path;
    }

    final promptBaseline = language == 'en'
        ? '🛠️  Baseline Options:\n  1) Analyze normally (default)\n  2) Create new baseline (ignore future identical issues)\n  3) Use existing baseline (filter out known issues)\nSelect (1/2/3) [1]: '
        : '🛠️  Baseline Seçenekleri:\n  1) Normal analiz et (varsayılan)\n  2) Yeni baseline oluştur (mevcut hataları gelecekte yoksay)\n  3) Mevcut baseline kullan (bilinen hataları gizle)\nSeçiminiz (1/2/3) [1]: ';
    stdout.write(promptBaseline);
    final baselineInput = stdin.readLineSync()?.trim();
    if (baselineInput == '2') {
      createBaseline = true;
    } else if (baselineInput == '3') {
      useBaselinePath = p.join(targetPath, 'baseline.json');
    }
  } else {
    // Normal komut satırı çalışması
    if (results.rest.isEmpty) {
      targetPath = Directory.current.path;
    } else {
      targetPath = results.rest.first;
      if (targetPath == '.') {
        targetPath = Directory.current.path;
      }
    }
  }

  // Hedef dizin kontrolü
  final targetDir = Directory(targetPath);
  if (!targetDir.existsSync()) {
    stderr.writeln(language == 'en'
        ? '❌ Error: Directory not found: $targetPath'
        : '❌ Hata: Dizin bulunamadı: $targetPath');
    exit(1);
  }

  // Konfigürasyon yükle
  final config = configPath != null
      ? AnalyzerConfig.fromYamlFile(configPath)
      : AnalyzerConfig.fromYamlFile(p.join(targetPath, 'analysis_options.yaml'));

  // Runner oluştur
  final runner = AnalyzerRunner(config: config);

  // Analiz başlat
  stderr.writeln('🔍 Flutter Deep Analyzer');
  stderr.writeln(language == 'en'
      ? '📂 Analyzing: ${p.absolute(targetPath)}'
      : '📂 Analiz ediliyor: ${p.absolute(targetPath)}');
  stderr.writeln();

  final result = categoryFilter != null
      ? await runner.analyzeCategory(targetPath, _parseCategory(categoryFilter))
      : await runner.analyzeDirectory(targetPath);

  // Baseline İşlemleri
  AnalysisResult finalResult = result;

  if (useBaselinePath != null) {
    final baselineManager = BaselineManager();
    await baselineManager.loadBaseline(useBaselinePath);
    final filteredIssues = baselineManager.filterIssues(result.issues);

    finalResult = AnalysisResult(
      issues: filteredIssues,
      timestamp: result.timestamp,
      projectPath: result.projectPath,
      analysisDuration: result.analysisDuration,
      totalFilesAnalyzed: result.totalFilesAnalyzed,
    );
  }

  if (createBaseline) {
    final baselinePath = p.join(targetPath, 'baseline.json');
    await BaselineManager.createBaseline(finalResult.issues, baselinePath);
    stderr.writeln(language == 'en'
        ? '✅ Baseline created: \$baselinePath'
        : '✅ Baseline oluşturuldu: \$baselinePath');
    exit(0);
  }

  // Puanla
  final scorer = ProjectScorer();
  final score = scorer.score(finalResult);

  // Raporla
  final reporter = _createReporter(format, language);
  final report = reporter.report(finalResult, score);

  // Çıktı
  if (outputPath != null) {
    if (format == 'html' && !outputPath.endsWith('.html')) outputPath += '.html';
    if (format == 'json' && !outputPath.endsWith('.json')) outputPath += '.json';
    if (format == 'markdown' && !outputPath.endsWith('.md')) outputPath += '.md';

    final outputFile = File(outputPath);
    await outputFile.writeAsString(report);
    stderr.writeln(
        language == 'en' ? '📄 Report saved: $outputPath' : '📄 Rapor kaydedildi: $outputPath');
  } else if (format != 'console') {
    // Console dışı formatlarda otomatik dosya kaydı
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final ext = format == 'markdown' ? 'md' : format;
    final reportDirPath = p.join(targetPath, 'flutter_deep_analyzer');
    final reportDir = Directory(reportDirPath);
    if (!reportDir.existsSync()) {
      reportDir.createSync(recursive: true);
    }
    final reportFileName = 'report_$timestamp.$ext';
    final reportFilePath = p.join(reportDirPath, reportFileName);
    final reportFile = File(reportFilePath);
    await reportFile.writeAsString(report);
    stderr.writeln(language == 'en'
        ? '📄 Report saved: $reportFilePath'
        : '📄 Rapor kaydedildi: $reportFilePath');
  } else {
    print(report);
  }

  // Konsola kısa bir özet geç (eğer çıktı formatı console değilse de kullanıcının haberi olsun)
  if (format != 'console') {
    stderr.writeln();
    stderr.writeln('----------------------------------------------------------');
    final resultStr = language == 'en' ? 'Result' : 'Sonuç';
    stderr.writeln(
      '${score.gradeEmoji} $resultStr: ${score.overallScore.toStringAsFixed(1)}/100 (${score.grade})',
    );
    if (language == 'en') {
      stderr.writeln(
          '🔴 Errors: ${finalResult.errorCount} | 🟡 Warnings: ${finalResult.warningCount} | 🔵 Info: ${finalResult.infoCount}');
    } else {
      stderr.writeln(
          '🔴 Hatalar: ${finalResult.errorCount} | 🟡 Uyarılar: ${finalResult.warningCount} | 🔵 Bilgi: ${finalResult.infoCount}');
    }
  }

  // Hata varsa exit code 1
  if (finalResult.errorCount > 0) {
    exit(1);
  }
}

BaseReporter _createReporter(String format, String language) {
  switch (format) {
    case 'json':
      return JsonReporter();
    case 'sonarqube':
      return SonarQubeReporter();
    case 'html':
      return HtmlReporter(language: language);
    case 'markdown':
      return MarkdownReporter(language: language);
    case 'console':
    default:
      return ConsoleReporter(language: language);
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
    case 'type_safety':
      return IssueCategory.typeSafety;
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
  flutter_deep_analyzer analyze --format=markdown --output=report.md .
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
