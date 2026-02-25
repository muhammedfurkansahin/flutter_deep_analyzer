// ignore_for_file: unused_local_variable

import 'package:flutter_deep_analyzer/flutter_deep_analyzer.dart';

/// Basic usage example for flutter_deep_analyzer.
///
/// This example demonstrates how to configure and run the analyzer
/// on a Flutter/Dart project directory.
Future<void> main() async {
  // Create analyzer configuration with defaults
  final config = AnalyzerConfig.defaults();

  // Or create a custom configuration
  final customConfig = AnalyzerConfig(
    categories: {
      'architecture': CategoryConfig(thresholds: {'god_class_threshold': 15}),
      'code_quality': CategoryConfig(thresholds: {'max_method_lines': 60}),
      'best_practice': const CategoryConfig(),
      'security': const CategoryConfig(),
      'race_condition': const CategoryConfig(),
      'performance': const CategoryConfig(),
      'memory_leak': const CategoryConfig(),
    },
    excludePatterns: [
      '.dart_tool/**',
      'build/**',
      '**/*.g.dart',
      '**/*.freezed.dart',
    ],
  );

  // Create and run the analyzer
  final runner = AnalyzerRunner(config: config);
  final result = await runner.analyzeDirectory('.');

  // Print summary
  print('Files analyzed: ${result.totalFilesAnalyzed}');
  print('Total issues: ${result.issues.length}');
  print('Errors: ${result.errorCount}');
  print('Warnings: ${result.warningCount}');
  print('Info: ${result.infoCount}');
  print('Duration: ${result.analysisDuration.inSeconds}s');

  // Calculate project score
  final scorer = ProjectScorer();
  final projectScore = scorer.score(result);
  print('Project Score: ${projectScore.overallScore.toStringAsFixed(1)}/100');

  // Generate console report
  final consoleReporter = ConsoleReporter();
  final consoleOutput = consoleReporter.report(result, projectScore);
  print(consoleOutput);

  // Generate JSON report
  final jsonReporter = JsonReporter();
  final jsonOutput = jsonReporter.report(result, projectScore);
  print(jsonOutput);
}
