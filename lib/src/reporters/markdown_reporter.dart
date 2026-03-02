import '../models/issue.dart';
import '../models/analysis_result.dart';
import '../models/score.dart';
import 'base_reporter.dart';

/// Markdown formatında rapor üreten reporter.
/// GitHub, GitLab gibi platformlarda ve IDE'lerde görsel olarak zengin bir çıktı sağlar.
class MarkdownReporter extends BaseReporter {
  final String language;

  MarkdownReporter({this.language = 'tr'});

  @override
  String report(AnalysisResult result, ProjectScore score) {
    final buffer = StringBuffer();

    // Title
    buffer.writeln('# 🔍 Flutter Deep Analyzer Report');
    buffer.writeln();
    if (language == 'en') {
      buffer.writeln('**Analysis Date:** ${result.timestamp.toLocal()}  ');
      buffer.writeln('**Project Path:** `${result.projectPath}`');
    } else {
      buffer.writeln('**Analiz Tarihi:** ${result.timestamp.toLocal()}  ');
      buffer.writeln('**Proje Dizini:** `${result.projectPath}`');
    }
    buffer.writeln();

    // Score Summary
    buffer.writeln(language == 'en' ? '## 📊 Overall Score' : '## 📊 Genel Puan');
    buffer.writeln();
    buffer.writeln('| Grade | Score |');
    buffer.writeln('| :---: | :---: |');
    buffer.writeln(
        '| **${score.gradeEmoji} ${score.grade}** | **${score.overallScore.toStringAsFixed(1)} / 100** |');
    buffer.writeln();

    // General Summary
    buffer.writeln(language == 'en' ? '## 📈 Summary' : '## 📈 Özet');
    buffer.writeln();
    buffer.writeln('| 🔴 Error | 🟡 Warning | 🔵 Info | ⚪ Style | 📄 Files | ⏱️ Duration |');
    buffer.writeln('|:---:|:---:|:---:|:---:|:---:|:---:|');
    buffer.writeln(
        '| **${result.errorCount}** | **${result.warningCount}** | **${result.infoCount}** | **${result.styleCount}** | **${result.totalFilesAnalyzed}** | **${result.analysisDuration.inMilliseconds}ms** |');
    buffer.writeln();

    // Category Scores
    buffer.writeln(language == 'en' ? '## 🎯 Category Scores' : '## 🎯 Kategori Puanları');
    buffer.writeln();
    buffer.writeln('| Category | Grade | Score | E | W | I | S |');
    buffer.writeln('| :--- | :---: | :---: | :---: | :---: | :---: | :---: |');
    for (final cat in score.categoryScores) {
      buffer.writeln(
          '| ${cat.categoryLabel} | ${cat.gradeEmoji} **${cat.grade}** | ${cat.score.toStringAsFixed(1)} | ${cat.errorCount} | ${cat.warningCount} | ${cat.infoCount} | ${cat.styleCount} |');
    }
    buffer.writeln();

    // Issues
    if (result.issues.isEmpty) {
      buffer.writeln(language == 'en'
          ? '## ✅ Awesome! No issues found!'
          : '## ✅ Harika! Hiçbir sorun bulunamadı!');
    } else {
      buffer.writeln(language == 'en'
          ? '## 📋 Detailed Issues (${result.issues.length})'
          : '## 📋 Detaylı Sorunlar (${result.issues.length})');
      buffer.writeln();

      final issuesByFile = <String, List<Issue>>{};
      for (final issue in result.issues) {
        issuesByFile.putIfAbsent(issue.filePath, () => []).add(issue);
      }

      for (final entry in issuesByFile.entries) {
        final file = entry.key;
        final fileIssues = entry.value;

        buffer.writeln('### 📄 `$file`');
        buffer.writeln();
        fileIssues.sort((a, b) => a.severity.index.compareTo(b.severity.index));

        for (final issue in fileIssues) {
          buffer.writeln(
              '- **${issue.severityEmoji} [${issue.severityLabel}]** - `${issue.ruleId}` (${issue.categoryLabel})');
          final lineStr = language == 'en' ? 'Line' : 'Satır';
          buffer.writeln('  - 📍 *$lineStr ${issue.line}*');
          buffer.writeln('  - 💬 ${issue.message}');
          if (issue.suggestion != null) {
            buffer.writeln('  - 💡 _${issue.suggestion}_');
          }
          if (issue.codeSnippet != null) {
            final lines = issue.codeSnippet!.split('\\n');
            buffer.writeln('  - 📝 **Code:**');
            buffer.writeln('    ```dart');
            for (final line in lines) {
              buffer.writeln('    $line');
            }
            buffer.writeln('    ```');
          }
        }
        buffer.writeln();
      }
    }

    buffer.writeln('---');
    buffer.writeln('💡 _Powered by Flutter Deep Analyzer_');

    return buffer.toString();
  }
}
