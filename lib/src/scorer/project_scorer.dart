import '../models/issue.dart';
import '../models/analysis_result.dart';
import '../models/score.dart';

/// Projeni puanlayan motor.
///
/// Puanlama formülü: 100 - (Σ ağırlıklı_ceza)
/// Error = -5, Warning = -2, Info = -0.5, Style = -0.25
/// Minimum puan: 0
class ProjectScorer {
  /// Issue severity'lerine göre ceza ağırlıkları
  static const _penalties = {
    Severity.error: 5.0,
    Severity.warning: 2.0,
    Severity.info: 0.5,
    Severity.style: 0.25,
  };

  /// Analiz sonuçlarını puanla.
  ProjectScore score(AnalysisResult result) {
    final categoryScores = <CategoryScore>[];

    for (final category in IssueCategory.values) {
      final categoryIssues = result.byCategory(category);
      final categoryScore = _calculateCategoryScore(category, categoryIssues);
      categoryScores.add(categoryScore);
    }

    // Genel puan: Tüm kategorilerin ağırlıklı ortalaması
    final overallScore = _calculateOverallScore(categoryScores);

    return ProjectScore(overallScore: overallScore, categoryScores: categoryScores);
  }

  CategoryScore _calculateCategoryScore(IssueCategory category, List<Issue> issues) {
    var totalPenalty = 0.0;

    final errors = issues.where((i) => i.severity == Severity.error).length;
    final warnings = issues.where((i) => i.severity == Severity.warning).length;
    final infos = issues.where((i) => i.severity == Severity.info).length;
    final styles = issues.where((i) => i.severity == Severity.style).length;

    totalPenalty += errors * _penalties[Severity.error]!;
    totalPenalty += warnings * _penalties[Severity.warning]!;
    totalPenalty += infos * _penalties[Severity.info]!;
    totalPenalty += styles * _penalties[Severity.style]!;

    // Puan: 100 - ceza, minimum 0
    final score = (100 - totalPenalty).clamp(0.0, 100.0);

    return CategoryScore(
      category: category,
      score: score,
      issueCount: issues.length,
      errorCount: errors,
      warningCount: warnings,
      infoCount: infos,
      styleCount: styles,
    );
  }

  double _calculateOverallScore(List<CategoryScore> scores) {
    if (scores.isEmpty) return 100.0;

    // Ağırlıklı ortalama - güvenlik ve bellek sızıntısı daha ağırlıklı
    const weights = {
      IssueCategory.architecture: 1.2,
      IssueCategory.codeQuality: 1.0,
      IssueCategory.bestPractice: 0.8,
      IssueCategory.security: 1.5,
      IssueCategory.raceCondition: 1.3,
      IssueCategory.performance: 1.1,
      IssueCategory.memoryLeak: 1.4,
    };

    var weightedSum = 0.0;
    var totalWeight = 0.0;

    for (final score in scores) {
      final weight = weights[score.category] ?? 1.0;
      weightedSum += score.score * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? (weightedSum / totalWeight).clamp(0.0, 100.0) : 100.0;
  }
}
