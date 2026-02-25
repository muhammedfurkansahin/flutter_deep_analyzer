import 'issue.dart';

/// Kategori bazlı puan.
class CategoryScore {
  final IssueCategory category;
  final double score;
  final int issueCount;
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final int styleCount;

  const CategoryScore({
    required this.category,
    required this.score,
    required this.issueCount,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    required this.styleCount,
  });

  String get grade {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  String get gradeEmoji {
    switch (grade) {
      case 'A':
        return '🟢';
      case 'B':
        return '🔵';
      case 'C':
        return '🟡';
      case 'D':
        return '🟠';
      default:
        return '🔴';
    }
  }

  String get categoryLabel {
    switch (category) {
      case IssueCategory.architecture:
        return 'Mimari';
      case IssueCategory.codeQuality:
        return 'Kod Kalitesi';
      case IssueCategory.bestPractice:
        return 'Best Practice';
      case IssueCategory.security:
        return 'Güvenlik';
      case IssueCategory.raceCondition:
        return 'Race Condition';
      case IssueCategory.performance:
        return 'Performans';
      case IssueCategory.memoryLeak:
        return 'Bellek Sızıntısı';
    }
  }

  Map<String, dynamic> toJson() => {
    'category': category.name,
    'score': score,
    'grade': grade,
    'issueCount': issueCount,
    'errors': errorCount,
    'warnings': warningCount,
    'infos': infoCount,
    'styles': styleCount,
  };
}

/// Projenin genel puanı.
class ProjectScore {
  final double overallScore;
  final List<CategoryScore> categoryScores;

  const ProjectScore({required this.overallScore, required this.categoryScores});

  String get grade {
    if (overallScore >= 90) return 'A';
    if (overallScore >= 80) return 'B';
    if (overallScore >= 70) return 'C';
    if (overallScore >= 60) return 'D';
    return 'F';
  }

  String get gradeEmoji {
    switch (grade) {
      case 'A':
        return '🟢';
      case 'B':
        return '🔵';
      case 'C':
        return '🟡';
      case 'D':
        return '🟠';
      default:
        return '🔴';
    }
  }

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'grade': grade,
    'categories': categoryScores.map((c) => c.toJson()).toList(),
  };
}
