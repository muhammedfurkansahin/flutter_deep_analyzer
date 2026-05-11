import '../models/analysis_result.dart';
import '../models/issue.dart';

/// HTML raporu için özet istatistikler (DCM tarzı paneller).
class HtmlReportAggregates {
  final Map<IssueCategory, int> issuesByCategory;
  final Map<String, int> issuesByRuleId;
  final List<DirectoryIssueBucket> directoryBuckets;
  final int totalIssues;
  final int distinctRules;

  const HtmlReportAggregates({
    required this.issuesByCategory,
    required this.issuesByRuleId,
    required this.directoryBuckets,
    required this.totalIssues,
    required this.distinctRules,
  });

  /// Analiz edilen dosya başına düşen bulgu (büyük projelerde bağlam için).
  double issuesPerAnalyzedFile(int totalFilesAnalyzed) {
    if (totalFilesAnalyzed <= 0) return 0;
    return totalIssues / totalFilesAnalyzed;
  }

  factory HtmlReportAggregates.from(AnalysisResult result) {
    final byCat = <IssueCategory, int>{};
    final byRule = <String, int>{};
    final dirMap = <String, _DirAgg>{};

    for (final c in IssueCategory.values) {
      byCat[c] = 0;
    }

    for (final issue in result.issues) {
      byCat[issue.category] = (byCat[issue.category] ?? 0) + 1;
      byRule[issue.ruleId] = (byRule[issue.ruleId] ?? 0) + 1;

      final bucket = _bucketPath(issue.filePath);
      final agg = dirMap.putIfAbsent(bucket, () => _DirAgg());
      switch (issue.severity) {
        case Severity.error:
          agg.errors++;
          break;
        case Severity.warning:
          agg.warnings++;
          break;
        case Severity.info:
          agg.infos++;
          break;
        case Severity.style:
          agg.styles++;
          break;
      }
    }

    final buckets = dirMap.entries
        .map(
          (e) => DirectoryIssueBucket(
            path: e.key,
            errors: e.value.errors,
            warnings: e.value.warnings,
            infos: e.value.infos,
            styles: e.value.styles,
          ),
        )
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return HtmlReportAggregates(
      issuesByCategory: byCat,
      issuesByRuleId: byRule,
      directoryBuckets: buckets,
      totalIssues: result.issues.length,
      distinctRules: byRule.length,
    );
  }

  /// Kural ID → tekrar sayısı, azalan sırada.
  List<MapEntry<String, int>> topRules({int limit = 25}) {
    final entries = issuesByRuleId.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.length <= limit) return entries;
    return entries.sublist(0, limit);
  }
}

class DirectoryIssueBucket {
  final String path;
  final int errors;
  final int warnings;
  final int infos;
  final int styles;

  const DirectoryIssueBucket({
    required this.path,
    required this.errors,
    required this.warnings,
    required this.infos,
    required this.styles,
  });

  int get total => errors + warnings + infos + styles;
}

class _DirAgg {
  int errors = 0;
  int warnings = 0;
  int infos = 0;
  int styles = 0;
}

/// İlk birkaç path segmentinde grupla (çok satır üretmeden dizin özeti).
String _bucketPath(String filePath) {
  final norm = filePath.replaceAll(r'\', '/');
  final parts = norm.split('/').where((s) => s.isNotEmpty).toList();
  if (parts.length <= 3) return norm;
  return parts.take(3).join('/');
}
