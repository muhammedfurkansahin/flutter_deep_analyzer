/// Analiz sonuçlarının şiddet derecesi.
enum Severity {
  /// Kritik hata, mutlaka düzeltilmeli.
  error,

  /// Uyarı, düzeltilmesi tavsiye edilir.
  warning,

  /// Bilgi, iyileştirme önerisi.
  info,

  /// Stil, kozmetik iyileştirme.
  style,
}

/// Analiz kategorileri.
enum IssueCategory {
  architecture,
  codeQuality,
  bestPractice,
  security,
  raceCondition,
  performance,
  memoryLeak,
  typeSafety,
}

/// Tek bir analiz bulgusu.
class Issue {
  final String ruleId;
  final Severity severity;
  final IssueCategory category;
  final String message;
  final String filePath;
  final int line;
  final int column;
  final String? suggestion;
  final String? codeSnippet;

  const Issue({
    required this.ruleId,
    required this.severity,
    required this.category,
    required this.message,
    required this.filePath,
    required this.line,
    this.column = 0,
    this.suggestion,
    this.codeSnippet,
  });

  String get severityLabel {
    switch (severity) {
      case Severity.error:
        return 'ERROR';
      case Severity.warning:
        return 'WARNING';
      case Severity.info:
        return 'INFO';
      case Severity.style:
        return 'STYLE';
    }
  }

  String get severityEmoji {
    switch (severity) {
      case Severity.error:
        return '🔴';
      case Severity.warning:
        return '🟡';
      case Severity.info:
        return '🔵';
      case Severity.style:
        return '⚪';
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
      case IssueCategory.typeSafety:
        return 'Tip Güvenliği';
    }
  }

  Map<String, dynamic> toJson() => {
        'ruleId': ruleId,
        'severity': severity.name,
        'category': category.name,
        'message': message,
        'filePath': filePath,
        'line': line,
        'column': column,
        if (suggestion != null) 'suggestion': suggestion,
        if (codeSnippet != null) 'codeSnippet': codeSnippet,
      };

  @override
  String toString() => '$severityEmoji [$severityLabel] $filePath:$line — $message';
}
