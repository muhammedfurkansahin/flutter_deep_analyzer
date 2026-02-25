import 'issue.dart';

/// Tüm analizerlerin sonuçlarını toplayan model.
class AnalysisResult {
  final List<Issue> issues;
  final DateTime timestamp;
  final String projectPath;
  final Duration analysisDuration;
  final int totalFilesAnalyzed;

  const AnalysisResult({
    required this.issues,
    required this.timestamp,
    required this.projectPath,
    required this.analysisDuration,
    required this.totalFilesAnalyzed,
  });

  /// Severity'ye göre filtrele.
  List<Issue> bySeverity(Severity severity) => issues.where((i) => i.severity == severity).toList();

  /// Kategoriye göre filtrele.
  List<Issue> byCategory(IssueCategory category) =>
      issues.where((i) => i.category == category).toList();

  /// Dosyaya göre filtrele.
  List<Issue> byFile(String filePath) => issues.where((i) => i.filePath == filePath).toList();

  int get errorCount => bySeverity(Severity.error).length;
  int get warningCount => bySeverity(Severity.warning).length;
  int get infoCount => bySeverity(Severity.info).length;
  int get styleCount => bySeverity(Severity.style).length;

  /// Etkilenen benzersiz dosya sayısı.
  int get affectedFileCount => issues.map((i) => i.filePath).toSet().length;

  Map<String, dynamic> toJson() => {
    'projectPath': projectPath,
    'timestamp': timestamp.toIso8601String(),
    'analysisDuration': analysisDuration.inMilliseconds,
    'totalFilesAnalyzed': totalFilesAnalyzed,
    'summary': {
      'totalIssues': issues.length,
      'errors': errorCount,
      'warnings': warningCount,
      'infos': infoCount,
      'styles': styleCount,
      'affectedFiles': affectedFileCount,
    },
    'issues': issues.map((i) => i.toJson()).toList(),
  };
}
