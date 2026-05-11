import 'dart:math' as math;

import '../models/issue.dart';
import '../models/analysis_result.dart';
import '../models/score.dart';

/// Projeni puanlayan motor.
///
/// Puanlama formülü: 100 - (Σ ağirlikli_ceza)
/// Error = -5, Warning = -2, Info = -0.5, Style = -0.25
/// Minimum puan: 0
///
/// Büyük kod tabanlarinda bilgi düzeyindeki gürültünün skoru gereksiz düşürmemesi için,
/// analiz edilen dosya sayisi [referansDosyaSayisi]'i aştiğinda ceza alt ölçeklenir (DCM benzeri bağlam).
class ProjectScorer {
  /// Bu dosya sayisina kadar ölçekleme uygulanmaz; üzerinde ceza `sqrt(ref/n)` ile azaltilir.
  static const int referansDosyaSayisi = 40;

  /// Issue severity'lerine göre ceza ağirliklari
  static const _penalties = {
    Severity.error: 5.0,
    Severity.warning: 2.0,
    Severity.info: 0.5,
    Severity.style: 0.25,
  };

  /// Analiz sonuçlarini puanla.
  ProjectScore score(AnalysisResult result) {
    final scale = _largeProjectPenaltyScale(result.totalFilesAnalyzed);
    final categoryScores = <CategoryScore>[];

    for (final category in IssueCategory.values) {
      final categoryIssues = result.byCategory(category);
      final categoryScore =
          _calculateCategoryScore(category, categoryIssues, scale);
      categoryScores.add(categoryScore);
    }

    // Genel puan: Tüm kategorilerin ağirlikli ortalamasi
    final overallScore = _calculateOverallScore(categoryScores);

    return ProjectScore(
        overallScore: overallScore, categoryScores: categoryScores);
  }

  /// Çok dosyali projelerde toplam cezayi düşürür; yapi sağlam olsa da çok sayida küçük uyarida skoru daha anlamli yapar.
  double _largeProjectPenaltyScale(int filesAnalyzed) {
    final n = math.max(1, filesAnalyzed);
    if (n <= referansDosyaSayisi) return 1.0;
    return math.sqrt(referansDosyaSayisi / n);
  }

  CategoryScore _calculateCategoryScore(
    IssueCategory category,
    List<Issue> issues,
    double penaltyScale,
  ) {
    var totalPenalty = 0.0;

    final errors = issues.where((i) => i.severity == Severity.error).length;
    final warnings = issues.where((i) => i.severity == Severity.warning).length;
    final infos = issues.where((i) => i.severity == Severity.info).length;
    final styles = issues.where((i) => i.severity == Severity.style).length;

    totalPenalty += errors * _penalties[Severity.error]!;
    totalPenalty += warnings * _penalties[Severity.warning]!;
    totalPenalty += infos * _penalties[Severity.info]!;
    totalPenalty += styles * _penalties[Severity.style]!;

    totalPenalty *= penaltyScale;

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

    // Ağirlikli ortalama - güvenlik ve bellek sizintisi daha ağirlikli
    const weights = {
      IssueCategory.architecture: 1.2,
      IssueCategory.codeQuality: 1.0,
      IssueCategory.bestPractice: 0.8,
      IssueCategory.security: 1.5,
      IssueCategory.raceCondition: 1.3,
      IssueCategory.performance: 1.1,
      IssueCategory.memoryLeak: 1.4,
      IssueCategory.typeSafety: 1.35,
    };

    var weightedSum = 0.0;
    var totalWeight = 0.0;

    for (final score in scores) {
      final weight = weights[score.category] ?? 1.0;
      weightedSum += score.score * weight;
      totalWeight += weight;
    }

    return totalWeight > 0
        ? (weightedSum / totalWeight).clamp(0.0, 100.0)
        : 100.0;
  }
}
