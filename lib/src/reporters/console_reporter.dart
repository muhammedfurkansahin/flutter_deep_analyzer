import '../models/issue.dart';
import '../models/analysis_result.dart';
import '../models/score.dart';
import 'base_reporter.dart';

/// Renkli konsol çıktısı üreten reporter.
class ConsoleReporter extends BaseReporter {
  // ANSI renk kodları
  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _dim = '\x1B[2m';
  static const _red = '\x1B[31m';
  static const _green = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _blue = '\x1B[34m';
  static const _magenta = '\x1B[35m';
  static const _cyan = '\x1B[36m';
  static const _white = '\x1B[37m';

  @override
  String report(AnalysisResult result, ProjectScore score) {
    final buffer = StringBuffer();

    _writeHeader(buffer);
    _writeSummary(buffer, result, score);
    _writeCategoryScores(buffer, score);
    _writeIssues(buffer, result);
    _writeFooter(buffer, result, score);

    return buffer.toString();
  }

  void _writeHeader(StringBuffer buffer) {
    buffer.writeln();
    buffer.writeln(
      '$_bold$_cyan╔══════════════════════════════════════════════════════════╗$_reset',
    );
    buffer.writeln(
      '$_bold$_cyan║           🔍 Flutter Deep Analyzer Report               ║$_reset',
    );
    buffer.writeln(
      '$_bold$_cyan╚══════════════════════════════════════════════════════════╝$_reset',
    );
    buffer.writeln();
  }

  void _writeSummary(StringBuffer buffer, AnalysisResult result, ProjectScore score) {
    buffer.writeln('$_bold📊 GENEL ÖZET$_reset');
    buffer.writeln('$_dim${'─' * 58}$_reset');

    final gradeColor = _getGradeColor(score.grade);
    buffer.writeln(
      '  Genel Puan:  $gradeColor$_bold${score.overallScore.toStringAsFixed(1)}/100 (${score.grade})$_reset',
    );
    buffer.writeln('  Toplam Sorun: $_bold${result.issues.length}$_reset');
    buffer.writeln(
      '  🔴 Error: $_red${result.errorCount}$_reset  '
      '🟡 Warning: $_yellow${result.warningCount}$_reset  '
      '🔵 Info: $_blue${result.infoCount}$_reset  '
      '⚪ Style: $_dim${result.styleCount}$_reset',
    );
    buffer.writeln('  Analiz Edilen Dosya: $_bold${result.totalFilesAnalyzed}$_reset');
    buffer.writeln('  Etkilenen Dosya: $_bold${result.affectedFileCount}$_reset');
    buffer.writeln('  Süre: $_bold${result.analysisDuration.inMilliseconds}ms$_reset');
    buffer.writeln();
  }

  void _writeCategoryScores(StringBuffer buffer, ProjectScore score) {
    buffer.writeln('$_bold📈 KATEGORİ PUANLARI$_reset');
    buffer.writeln('$_dim${'─' * 58}$_reset');

    for (final cat in score.categoryScores) {
      if (cat.issueCount == 0 && cat.score == 100) continue;

      final gradeColor = _getGradeColor(cat.grade);
      final bar = _createProgressBar(cat.score, 30);

      buffer.writeln(
        '  ${cat.gradeEmoji} ${_padRight(cat.categoryLabel, 20)} '
        '$bar $gradeColor${cat.score.toStringAsFixed(1)}$_reset '
        '(${cat.grade}) '
        '$_dim[E:${cat.errorCount} W:${cat.warningCount} I:${cat.infoCount}]$_reset',
      );
    }
    buffer.writeln();
  }

  void _writeIssues(StringBuffer buffer, AnalysisResult result) {
    if (result.issues.isEmpty) {
      buffer.writeln('$_green$_bold✅ Harika! Hiçbir sorun bulunamadı!$_reset');
      buffer.writeln();
      return;
    }

    buffer.writeln('$_bold📋 DETAYLI SORUNLAR$_reset');
    buffer.writeln('$_dim${'─' * 58}$_reset');

    // Dosyaya göre grupla
    final issuesByFile = <String, List<Issue>>{};
    for (final issue in result.issues) {
      issuesByFile.putIfAbsent(issue.filePath, () => []).add(issue);
    }

    for (final entry in issuesByFile.entries) {
      final file = entry.key;
      final fileIssues = entry.value;

      buffer.writeln();
      buffer.writeln('  $_bold$_white📄 $file$_reset $_dim(${fileIssues.length} sorun)$_reset');

      // Severity'ye göre sırala
      fileIssues.sort((a, b) => a.severity.index.compareTo(b.severity.index));

      for (final issue in fileIssues) {
        final severityColor = _getSeverityColor(issue.severity);
        buffer.writeln(
          '    $severityColor${issue.severityEmoji} [${issue.severityLabel}]$_reset '
          '${issue.message}',
        );
        buffer.writeln(
          '      $_dim📍 Satır ${issue.line} | ${issue.ruleId} | ${issue.categoryLabel}$_reset',
        );

        if (issue.suggestion != null) {
          buffer.writeln('      $_green💡 ${issue.suggestion}$_reset');
        }
        if (issue.codeSnippet != null) {
          buffer.writeln('      $_dim📝 ${issue.codeSnippet}$_reset');
        }
      }
    }
    buffer.writeln();
  }

  void _writeFooter(StringBuffer buffer, AnalysisResult result, ProjectScore score) {
    buffer.writeln('$_dim${'─' * 58}$_reset');

    final gradeColor = _getGradeColor(score.grade);
    buffer.writeln(
      '$_bold Sonuç: $gradeColor${score.gradeEmoji} '
      '${score.overallScore.toStringAsFixed(1)}/100 (${score.grade})$_reset',
    );

    if (result.errorCount > 0) {
      buffer.writeln('$_red ⚠️  ${result.errorCount} kritik hata düzeltilmeli!$_reset');
    } else if (result.warningCount > 0) {
      buffer.writeln('$_yellow 💡 ${result.warningCount} uyarı gözden geçirilmeli.$_reset');
    } else {
      buffer.writeln('$_green ✨ Kod kalitesi çok iyi!$_reset');
    }

    buffer.writeln();
    buffer.writeln('$_dim Powered by Flutter Deep Analyzer v0.1.0$_reset');
    buffer.writeln();
  }

  String _createProgressBar(double value, int width) {
    final filled = (value / 100 * width).round();
    final empty = width - filled;

    final color = value >= 80
        ? _green
        : value >= 60
            ? _yellow
            : _red;

    return '$color${'█' * filled}$_dim${'░' * empty}$_reset';
  }

  String _getSeverityColor(Severity severity) {
    switch (severity) {
      case Severity.error:
        return _red;
      case Severity.warning:
        return _yellow;
      case Severity.info:
        return _blue;
      case Severity.style:
        return _dim;
    }
  }

  String _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return _green;
      case 'B':
        return _blue;
      case 'C':
        return _yellow;
      case 'D':
        return _magenta;
      default:
        return _red;
    }
  }

  String _padRight(String text, int width) {
    if (text.length >= width) return text;
    return text + ' ' * (width - text.length);
  }
}
