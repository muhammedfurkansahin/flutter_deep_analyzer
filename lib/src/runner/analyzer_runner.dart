import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart' hide AnalysisResult;
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:glob/glob.dart';

import '../analyzers/base_analyzer.dart';
import '../analyzers/architecture_analyzer.dart';
import '../analyzers/code_quality_analyzer.dart';
import '../analyzers/best_practice_analyzer.dart';
import '../analyzers/security_analyzer.dart';
import '../analyzers/race_condition_analyzer.dart';
import '../analyzers/performance_analyzer.dart';
import '../analyzers/memory_leak_analyzer.dart';
import '../config/analyzer_config.dart';
import '../models/issue.dart';
import '../models/analysis_result.dart';

/// Tüm analyzerleri orkestra eden runner.
class AnalyzerRunner {
  final AnalyzerConfig config;
  final List<BaseAnalyzer> _analyzers = [];

  AnalyzerRunner({required this.config}) {
    _initializeAnalyzers();
  }

  void _initializeAnalyzers() {
    if (config.isCategoryEnabled('architecture')) {
      _analyzers.add(ArchitectureAnalyzer(config: config));
    }
    if (config.isCategoryEnabled('code_quality')) {
      _analyzers.add(CodeQualityAnalyzer(config: config));
    }
    if (config.isCategoryEnabled('best_practice')) {
      _analyzers.add(BestPracticeAnalyzer(config: config));
    }
    if (config.isCategoryEnabled('security')) {
      _analyzers.add(SecurityAnalyzer(config: config));
    }
    if (config.isCategoryEnabled('race_condition')) {
      _analyzers.add(RaceConditionAnalyzer(config: config));
    }
    if (config.isCategoryEnabled('performance')) {
      _analyzers.add(PerformanceAnalyzer(config: config));
    }
    if (config.isCategoryEnabled('memory_leak')) {
      _analyzers.add(MemoryLeakAnalyzer(config: config));
    }
  }

  /// Belirli bir dizini analiz et.
  Future<AnalysisResult> analyzeDirectory(String directoryPath) async {
    final stopwatch = Stopwatch()..start();
    final absolutePath = p.absolute(directoryPath);

    // Dart dosyalarını bul
    final dartFiles = _findDartFiles(absolutePath);

    if (dartFiles.isEmpty) {
      stopwatch.stop();
      return AnalysisResult(
        issues: [],
        timestamp: DateTime.now(),
        projectPath: absolutePath,
        analysisDuration: stopwatch.elapsed,
        totalFilesAnalyzed: 0,
      );
    }

    // Analyzer context oluştur
    final collection = AnalysisContextCollection(
      includedPaths: [absolutePath],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final allIssues = <Issue>[];
    var filesAnalyzed = 0;

    for (final filePath in dartFiles) {
      if (_shouldExclude(filePath, absolutePath)) continue;

      try {
        final context = collection.contextFor(filePath);
        final result = await context.currentSession.getResolvedUnit(filePath);

        if (result is ResolvedUnitResult) {
          final fileContent = File(filePath).readAsStringSync();
          filesAnalyzed++;

          for (final analyzer in _analyzers) {
            try {
              final issues = await analyzer.analyze(
                result,
                p.relative(filePath, from: absolutePath),
                fileContent,
              );
              allIssues.addAll(issues);
            } catch (e) {
              // Analyzer hatası, devam et
              stderr.writeln('⚠️  ${analyzer.name} hatası ($filePath): $e');
            }
          }
        }
      } catch (e) {
        stderr.writeln('⚠️  Dosya analiz hatası ($filePath): $e');
      }
    }

    stopwatch.stop();

    return AnalysisResult(
      issues: allIssues,
      timestamp: DateTime.now(),
      projectPath: absolutePath,
      analysisDuration: stopwatch.elapsed,
      totalFilesAnalyzed: filesAnalyzed,
    );
  }

  /// Belirli bir kategoride analiz et.
  Future<AnalysisResult> analyzeCategory(String directoryPath, IssueCategory category) async {
    final result = await analyzeDirectory(directoryPath);
    return AnalysisResult(
      issues: result.byCategory(category),
      timestamp: result.timestamp,
      projectPath: result.projectPath,
      analysisDuration: result.analysisDuration,
      totalFilesAnalyzed: result.totalFilesAnalyzed,
    );
  }

  List<String> _findDartFiles(String directoryPath) {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => p.normalize(f.absolute.path))
        .toList();
  }

  bool _shouldExclude(String filePath, String rootPath) {
    final relativePath = p.relative(filePath, from: rootPath);

    for (final pattern in config.excludePatterns) {
      final glob = Glob(pattern);
      if (glob.matches(relativePath)) return true;
    }

    return false;
  }
}
