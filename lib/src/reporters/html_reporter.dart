import '../models/issue.dart';
import '../models/analysis_result.dart';
import '../models/score.dart';
import 'base_reporter.dart';

/// HTML formatında rapor üreten reporter.
/// Tarayıcıda açılabilir güzel rapor.
class HtmlReporter extends BaseReporter {
  @override
  String report(AnalysisResult result, ProjectScore score) {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="tr">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('<title>Flutter Deep Analyzer Report</title>');
    buffer.writeln('<style>');
    buffer.writeln(_getStyles());
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    // Header
    buffer.writeln('<div class="container">');
    buffer.writeln('<header>');
    buffer.writeln('<h1>🔍 Flutter Deep Analyzer Report</h1>');
    buffer.writeln('<p class="timestamp">Analiz: ${result.timestamp.toLocal()}</p>');
    buffer.writeln('<p class="path">Proje: ${result.projectPath}</p>');
    buffer.writeln('</header>');

    // Genel Puan
    buffer.writeln('<section class="score-section">');
    buffer.writeln('<div class="overall-score grade-${score.grade.toLowerCase()}">');
    buffer.writeln('<div class="score-value">${score.overallScore.toStringAsFixed(1)}</div>');
    buffer.writeln('<div class="score-grade">${score.grade}</div>');
    buffer.writeln('<div class="score-label">Genel Puan</div>');
    buffer.writeln('</div>');

    // Özet Kartlar
    buffer.writeln('<div class="summary-cards">');
    _writeSummaryCard(buffer, '🔴 Error', '${result.errorCount}', 'error');
    _writeSummaryCard(buffer, '🟡 Warning', '${result.warningCount}', 'warning');
    _writeSummaryCard(buffer, '🔵 Info', '${result.infoCount}', 'info');
    _writeSummaryCard(buffer, '⚪ Style', '${result.styleCount}', 'style');
    _writeSummaryCard(buffer, '📄 Dosya', '${result.totalFilesAnalyzed}', 'neutral');
    _writeSummaryCard(buffer, '⏱️ Süre', '${result.analysisDuration.inMilliseconds}ms', 'neutral');
    buffer.writeln('</div>');
    buffer.writeln('</section>');

    // Kategori Puanları
    buffer.writeln('<section class="categories-section">');
    buffer.writeln('<h2>📈 Kategori Puanları</h2>');
    buffer.writeln('<div class="category-grid">');
    for (final cat in score.categoryScores) {
      _writeCategoryCard(buffer, cat);
    }
    buffer.writeln('</div>');
    buffer.writeln('</section>');

    // Detaylı Sorunlar
    if (result.issues.isNotEmpty) {
      buffer.writeln('<section class="issues-section">');
      buffer.writeln('<h2>📋 Detaylı Sorunlar (${result.issues.length})</h2>');

      // Dosyaya göre grupla
      final issuesByFile = <String, List<Issue>>{};
      for (final issue in result.issues) {
        issuesByFile.putIfAbsent(issue.filePath, () => []).add(issue);
      }

      for (final entry in issuesByFile.entries) {
        buffer.writeln('<div class="file-group">');
        buffer.writeln('<h3>📄 ${entry.key} <span class="badge">${entry.value.length}</span></h3>');
        buffer.writeln('<table class="issues-table">');
        buffer.writeln(
          '<thead><tr><th>Severity</th><th>Kural</th><th>Satır</th><th>Mesaj</th><th>Öneri</th></tr></thead>',
        );
        buffer.writeln('<tbody>');

        entry.value.sort((a, b) => a.severity.index.compareTo(b.severity.index));
        for (final issue in entry.value) {
          buffer.writeln('<tr class="severity-${issue.severity.name}">');
          buffer.writeln(
            '<td><span class="severity-badge ${issue.severity.name}">${issue.severityLabel}</span></td>',
          );
          buffer.writeln('<td><code>${issue.ruleId}</code></td>');
          buffer.writeln('<td>${issue.line}</td>');
          buffer.writeln('<td>${_escapeHtml(issue.message)}</td>');
          buffer.writeln(
            '<td>${issue.suggestion != null ? _escapeHtml(issue.suggestion!) : "-"}</td>',
          );
          buffer.writeln('</tr>');
        }

        buffer.writeln('</tbody></table>');
        buffer.writeln('</div>');
      }
      buffer.writeln('</section>');
    } else {
      buffer.writeln('<section class="no-issues">');
      buffer.writeln('<h2>✅ Harika! Hiçbir sorun bulunamadı!</h2>');
      buffer.writeln('</section>');
    }

    buffer.writeln('<footer>Powered by Flutter Deep Analyzer v0.1.0</footer>');
    buffer.writeln('</div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  void _writeSummaryCard(StringBuffer buffer, String label, String value, String type) {
    buffer.writeln('<div class="summary-card $type">');
    buffer.writeln('<div class="card-value">$value</div>');
    buffer.writeln('<div class="card-label">$label</div>');
    buffer.writeln('</div>');
  }

  void _writeCategoryCard(StringBuffer buffer, CategoryScore cat) {
    buffer.writeln('<div class="category-card grade-${cat.grade.toLowerCase()}">');
    buffer.writeln('<div class="cat-header">');
    buffer.writeln('<span class="cat-name">${cat.gradeEmoji} ${cat.categoryLabel}</span>');
    buffer.writeln('<span class="cat-grade">${cat.grade}</span>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="progress-bar">');
    buffer.writeln('<div class="progress-fill" style="width: ${cat.score}%"></div>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="cat-score">${cat.score.toStringAsFixed(1)}/100</div>');
    buffer.writeln('<div class="cat-details">');
    buffer.writeln(
      'E: ${cat.errorCount} | W: ${cat.warningCount} | I: ${cat.infoCount} | S: ${cat.styleCount}',
    );
    buffer.writeln('</div>');
    buffer.writeln('</div>');
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  String _getStyles() {
    return '''
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: #0f172a; color: #e2e8f0; line-height: 1.6;
}
.container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
header { text-align: center; margin-bottom: 2rem; }
header h1 { font-size: 2rem; background: linear-gradient(135deg, #38bdf8, #818cf8); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
.timestamp, .path { color: #64748b; font-size: 0.9rem; }

.score-section { display: flex; flex-direction: column; align-items: center; gap: 2rem; margin-bottom: 3rem; }
.overall-score {
  width: 180px; height: 180px; border-radius: 50%;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  border: 4px solid; position: relative;
}
.grade-a { border-color: #22c55e; }
.grade-b { border-color: #3b82f6; }
.grade-c { border-color: #eab308; }
.grade-d { border-color: #f97316; }
.grade-f { border-color: #ef4444; }
.score-value { font-size: 2.5rem; font-weight: bold; }
.score-grade { font-size: 1.5rem; font-weight: bold; }
.score-label { font-size: 0.8rem; color: #94a3b8; }

.summary-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 1rem; width: 100%; }
.summary-card {
  background: #1e293b; border-radius: 12px; padding: 1rem; text-align: center;
  border: 1px solid #334155; transition: transform 0.2s;
}
.summary-card:hover { transform: translateY(-2px); }
.card-value { font-size: 1.8rem; font-weight: bold; }
.card-label { font-size: 0.85rem; color: #94a3b8; }
.summary-card.error .card-value { color: #ef4444; }
.summary-card.warning .card-value { color: #eab308; }
.summary-card.info .card-value { color: #3b82f6; }

h2 { margin-bottom: 1.5rem; font-size: 1.4rem; }

.category-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem; margin-bottom: 3rem; }
.category-card {
  background: #1e293b; border-radius: 12px; padding: 1.2rem;
  border-left: 4px solid; transition: transform 0.2s;
}
.category-card:hover { transform: translateY(-2px); }
.category-card.grade-a { border-left-color: #22c55e; }
.category-card.grade-b { border-left-color: #3b82f6; }
.category-card.grade-c { border-left-color: #eab308; }
.category-card.grade-d { border-left-color: #f97316; }
.category-card.grade-f { border-left-color: #ef4444; }
.cat-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.8rem; }
.cat-name { font-weight: 600; }
.cat-grade { font-size: 1.2rem; font-weight: bold; }
.progress-bar { height: 6px; background: #334155; border-radius: 3px; overflow: hidden; margin-bottom: 0.5rem; }
.progress-fill { height: 100%; border-radius: 3px; transition: width 0.5s ease; }
.grade-a .progress-fill { background: #22c55e; }
.grade-b .progress-fill { background: #3b82f6; }
.grade-c .progress-fill { background: #eab308; }
.grade-d .progress-fill { background: #f97316; }
.grade-f .progress-fill { background: #ef4444; }
.cat-score { font-size: 0.9rem; color: #94a3b8; }
.cat-details { font-size: 0.8rem; color: #64748b; margin-top: 0.3rem; }

.file-group { background: #1e293b; border-radius: 12px; padding: 1.2rem; margin-bottom: 1rem; }
.file-group h3 { font-size: 1rem; margin-bottom: 0.8rem; color: #38bdf8; }
.badge {
  background: #334155; color: #94a3b8; padding: 2px 8px; border-radius: 10px;
  font-size: 0.75rem; font-weight: normal;
}

.issues-table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
.issues-table th { text-align: left; padding: 0.6rem; color: #64748b; border-bottom: 1px solid #334155; }
.issues-table td { padding: 0.6rem; border-bottom: 1px solid #1e293b; vertical-align: top; }
.issues-table tr:hover { background: #253347; }

.severity-badge {
  padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: 600;
}
.severity-badge.error { background: rgba(239,68,68,0.2); color: #ef4444; }
.severity-badge.warning { background: rgba(234,179,8,0.2); color: #eab308; }
.severity-badge.info { background: rgba(59,130,246,0.2); color: #3b82f6; }
.severity-badge.style { background: rgba(148,163,184,0.2); color: #94a3b8; }

code { background: #334155; padding: 2px 6px; border-radius: 4px; font-size: 0.8rem; }

.no-issues { text-align: center; padding: 3rem; color: #22c55e; }

footer { text-align: center; color: #475569; font-size: 0.8rem; margin-top: 3rem; padding-top: 1rem; border-top: 1px solid #1e293b; }

@media (max-width: 768px) {
  .container { padding: 1rem; }
  .summary-cards { grid-template-columns: repeat(3, 1fr); }
  .category-grid { grid-template-columns: 1fr; }
}
''';
  }
}
