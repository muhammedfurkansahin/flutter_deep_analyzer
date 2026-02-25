/// Flutter Deep Analyzer
///
/// Flutter ve Dart projeleri için kapsamlı statik analiz aracı.
///
/// Analiz kategorileri:
/// - Mimari analizi
/// - Kod kalitesi
/// - Best practice
/// - Güvenlik açıkları
/// - Race condition tespiti
/// - Performans metrikleri
/// - Bellek sızıntısı tespiti
library;

// Models
export 'src/models/issue.dart';
export 'src/models/analysis_result.dart';
export 'src/models/score.dart';

// Analyzers
export 'src/analyzers/base_analyzer.dart';
export 'src/analyzers/architecture_analyzer.dart';
export 'src/analyzers/code_quality_analyzer.dart';
export 'src/analyzers/best_practice_analyzer.dart';
export 'src/analyzers/security_analyzer.dart';
export 'src/analyzers/race_condition_analyzer.dart';
export 'src/analyzers/performance_analyzer.dart';
export 'src/analyzers/memory_leak_analyzer.dart';

// Config
export 'src/config/analyzer_config.dart';

// Runner
export 'src/runner/analyzer_runner.dart';

// Scorer
export 'src/scorer/project_scorer.dart';

// Reporters
export 'src/reporters/base_reporter.dart';
export 'src/reporters/console_reporter.dart';
export 'src/reporters/json_reporter.dart';
export 'src/reporters/html_reporter.dart';
