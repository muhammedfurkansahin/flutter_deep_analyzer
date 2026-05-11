import '../models/issue.dart';
import '../models/analysis_result.dart';
import '../models/score.dart';
import '../scorer/project_scorer.dart';
import 'base_reporter.dart';
import 'html_report_aggregates.dart';

/// HTML formatında rapor üreten reporter (DCM tarzı paneller; otomatik düzeltme/quick fix yok).
class HtmlReporter extends BaseReporter {
  final String language;

  HtmlReporter({this.language = 'tr'});

  static const _packageVersion = '1.0.5';

  @override
  String report(AnalysisResult result, ProjectScore score) {
    final agg = HtmlReportAggregates.from(result);
    final buffer = StringBuffer();
    final isEn = language == 'en';

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="$language">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('<title>Flutter Deep Analyzer Report</title>');
    buffer.writeln('<style>');
    buffer.writeln(_getStyles());
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    buffer.writeln('<div class="container">');

    // Üst gezinme (DCM tarzı çok bölümlü rapor)
    buffer.writeln('<nav class="report-nav" aria-label="Report sections">');
    buffer.writeln(isEn
        ? '<a href="#overview">Overview</a>'
        : '<a href="#overview">Özet</a>');
    buffer.writeln(isEn
        ? '<a href="#metrics">Metrics</a>'
        : '<a href="#metrics">Metrikler</a>');
    buffer.writeln(isEn
        ? '<a href="#distribution">Distribution</a>'
        : '<a href="#distribution">Dağılım</a>');
    buffer.writeln(isEn
        ? '<a href="#directories">Directories</a>'
        : '<a href="#directories">Dizinler</a>');
    buffer.writeln(isEn
        ? '<a href="#rules">Rules</a>'
        : '<a href="#rules">Kurallar</a>');
    buffer.writeln(isEn ? '<a href="#issues">Issues</a>' : '<a href="#issues">Sorunlar</a>');
    buffer.writeln('</nav>');

    buffer.writeln('<header id="overview">');
    buffer.writeln('<h1>🔍 Flutter Deep Analyzer</h1>');
    buffer.writeln(isEn
        ? '<p class="timestamp">Analysis · ${result.timestamp.toLocal()}</p>'
        : '<p class="timestamp">Analiz · ${result.timestamp.toLocal()}</p>');
    buffer.writeln(
        '<p class="path">${isEn ? 'Project' : 'Proje'} · ${_escapeHtml(result.projectPath)}</p>');
    buffer.writeln(isEn
        ? '<p class="hint">This report lists findings only — apply fixes in your editor as you prefer (no automatic quick-fixes).</p>'
        : '<p class="hint">Bu rapor yalnızca bulguları listeler; düzeltmeleri editörünüzde siz uygularsınız (otomatik quick-fix yok).</p>');
    buffer.writeln(
        '<p class="scale-hint">${_scaleExplanation(result.totalFilesAnalyzed, isEn)}</p>');
    buffer.writeln('</header>');

    // Genel puan
    buffer.writeln('<section class="score-section">');
    buffer.writeln('<div class="overall-score grade-${score.grade.toLowerCase()}">');
    buffer.writeln('<div class="score-value">${score.overallScore.toStringAsFixed(1)}</div>');
    buffer.writeln('<div class="score-grade">${score.grade}</div>');
    buffer.writeln(
        '<div class="score-label">${isEn ? 'Overall score' : 'Genel puan'}</div>');
    buffer.writeln('</div>');

    buffer.writeln('<div class="summary-cards">');
    _writeSummaryCard(buffer, isEn ? 'Errors' : 'Hatalar', '${result.errorCount}', 'error',
        filterable: true);
    _writeSummaryCard(buffer, isEn ? 'Warnings' : 'Uyarılar', '${result.warningCount}', 'warning',
        filterable: true);
    _writeSummaryCard(buffer, isEn ? 'Info' : 'Bilgi', '${result.infoCount}', 'info',
        filterable: true);
    _writeSummaryCard(buffer, isEn ? 'Style' : 'Stil', '${result.styleCount}', 'style',
        filterable: true);
    _writeSummaryCard(
        buffer, isEn ? 'Files scanned' : 'Taranan dosya', '${result.totalFilesAnalyzed}', 'neutral');
    _writeSummaryCard(buffer, isEn ? 'Duration' : 'Süre',
        '${result.analysisDuration.inMilliseconds} ms', 'neutral');
    _writeSummaryCard(buffer, isEn ? 'Affected files' : 'Etkilenen dosya',
        '${result.affectedFileCount}', 'neutral');
    buffer.writeln('</div>');
    buffer.writeln('</section>');

    // Yoğunluk metrikleri
    buffer.writeln('<section class="panel" id="metrics">');
    buffer.writeln('<h2>${isEn ? '📐 Issue density' : '📐 Bulgu yoğunluğu'}</h2>');
    buffer.writeln('<div class="metric-grid">');
    _writeMetricTile(
      buffer,
      isEn ? 'Issues per scanned file' : 'Taranan dosya başına bulgu',
      agg.totalIssues > 0 && result.totalFilesAnalyzed > 0
          ? agg.issuesPerAnalyzedFile(result.totalFilesAnalyzed).toStringAsFixed(2)
          : '0',
      isEn ? 'avg issues / file' : 'ort. bulgu / dosya',
    );
    _writeMetricTile(
      buffer,
      isEn ? 'Distinct rule IDs' : 'Farklı kural sayısı',
      '${agg.distinctRules}',
      isEn ? 'unique rules triggered' : 'tetiklenen benzersiz kural',
    );
    _writeMetricTile(
      buffer,
      isEn ? 'Total findings' : 'Toplam bulgu',
      '${agg.totalIssues}',
      isEn ? 'all severities' : 'tüm şiddetler',
    );
    buffer.writeln('</div>');
    buffer.writeln('</section>');

    // Kategori kartları + Dağılım
    buffer.writeln('<section class="categories-section" id="distribution">');
    buffer.writeln(
        '<h2>${isEn ? '📈 Categories & severity mix' : '📈 Kategoriler ve şiddet dağılımı'}</h2>');
    buffer.writeln('<div class="two-col">');
    buffer.writeln('<div class="donut-wrap" aria-hidden="true">');
    buffer.writeln('<div class="donut-hole"></div>');
    buffer.writeln(
        '<div class="donut" style="background:${_donutGradient(result)}"></div>');
    buffer.writeln('<div class="donut-center">${agg.totalIssues}</div>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="legend">');
    buffer.writeln(_legendRow(isEn ? 'Error' : 'Hata', result.errorCount, '#ef4444'));
    buffer.writeln(_legendRow(isEn ? 'Warning' : 'Uyarı', result.warningCount, '#eab308'));
    buffer.writeln(_legendRow(isEn ? 'Info' : 'Bilgi', result.infoCount, '#3b82f6'));
    buffer.writeln(_legendRow(isEn ? 'Style' : 'Stil', result.styleCount, '#94a3b8'));
    buffer.writeln('</div>');
    buffer.writeln('</div>');

    buffer.writeln('<h3 class="subhead">${isEn ? 'Issues by category' : 'Kategoriye göre bulgular'}</h3>');
    final maxCat = agg.issuesByCategory.values.fold<int>(0, (a, b) => a > b ? a : b);
    buffer.writeln('<div class="category-bars">');
    for (final e in agg.issuesByCategory.entries) {
      if (e.value == 0) continue;
      final pct = maxCat > 0 ? (e.value / maxCat * 100).clamp(0.0, 100.0) : 0.0;
      buffer.writeln('<div class="cat-bar-row">');
      buffer.writeln(
          '<span class="cat-bar-label">${_categoryTitle(e.key, isEn)}</span>');
      buffer.writeln('<div class="cat-bar-track"><div class="cat-bar-fill" '
          'style="width:${pct.toStringAsFixed(1)}%"></div></div>');
      buffer.writeln('<span class="cat-bar-count">${e.value}</span>');
      buffer.writeln('</div>');
    }
    if (agg.issuesByCategory.values.every((v) => v == 0)) {
      buffer.writeln(
          '<p class="empty-note">${isEn ? 'No issues in this run.' : 'Bu çalıştırmada bulgu yok.'}</p>');
    }
    buffer.writeln('</div>');

    buffer.writeln('<div class="category-grid">');
    for (final cat in score.categoryScores) {
      _writeCategoryCard(buffer, cat, isEn);
    }
    buffer.writeln('</div>');
    buffer.writeln('</section>');

    // Dizin özeti
    if (agg.directoryBuckets.isNotEmpty) {
      buffer.writeln('<section class="panel" id="directories">');
      buffer.writeln(
          '<h2>${isEn ? '📂 Hot directories (first path segments)' : '📂 Yoğun dizinler (ilk path segmentleri)'}</h2>');
      buffer.writeln('<p class="panel-desc">${isEn ? 'Grouped by the first three path segments of each file — useful on large monorepos.' : 'Her dosyanın ilk üç path segmentine göre gruplanır — büyük projelerde yoğun alanları gösterir.'}</p>');
      buffer.writeln('<div class="table-scroll">');
      buffer.writeln('<table class="data-table">');
      buffer.writeln('<thead><tr>');
      buffer.writeln('<th>${isEn ? 'Directory' : 'Dizin'}</th>');
      buffer.writeln('<th>E</th><th>W</th><th>I</th><th>S</th>');
      buffer.writeln('<th>${isEn ? 'Total' : 'Toplam'}</th>');
      buffer.writeln('</tr></thead><tbody>');
      final limit = agg.directoryBuckets.length > 35 ? 35 : agg.directoryBuckets.length;
      for (var i = 0; i < limit; i++) {
        final d = agg.directoryBuckets[i];
        buffer.writeln('<tr>');
        buffer.writeln('<td><code>${_escapeHtml(d.path)}</code></td>');
        buffer.writeln('<td>${d.errors}</td><td>${d.warnings}</td>');
        buffer.writeln('<td>${d.infos}</td><td>${d.styles}</td>');
        buffer.writeln('<td><strong>${d.total}</strong></td>');
        buffer.writeln('</tr>');
      }
      buffer.writeln('</tbody></table>');
      buffer.writeln('</div>');
      buffer.writeln('</section>');
    }

    // En sık tetiklenen kurallar
    final topRules = agg.topRules(limit: 30);
    if (topRules.isNotEmpty) {
      buffer.writeln('<section class="panel" id="rules">');
      buffer.writeln(
          '<h2>${isEn ? '⚙️ Top rules (by count)' : '⚙️ En sık tetiklenen kurallar'}</h2>');
      buffer.writeln('<div class="table-scroll">');
      buffer.writeln('<table class="data-table rules-table">');
      buffer.writeln('<thead><tr>');
      buffer.writeln('<th>#</th>');
      buffer.writeln('<th>${isEn ? 'Rule ID' : 'Kural ID'}</th>');
      buffer.writeln('<th>${isEn ? 'Occurrences' : 'Tekrar'}</th>');
      buffer.writeln('</tr></thead><tbody>');
      var rank = 1;
      for (final e in topRules) {
        buffer.writeln('<tr>');
        buffer.writeln('<td>$rank</td>');
        buffer.writeln('<td><code>${_escapeHtml(e.key)}</code></td>');
        buffer.writeln('<td>${e.value}</td>');
        buffer.writeln('</tr>');
        rank++;
      }
      buffer.writeln('</tbody></table>');
      buffer.writeln('</div>');
      buffer.writeln('</section>');
    }

    // Detaylı Sorunlar
    if (result.issues.isNotEmpty) {
      buffer.writeln('<section class="issues-section" id="issues">');
      buffer.writeln(
          '<h2>${isEn ? 'Detailed issues' : 'Detaylı sorunlar'} (${result.issues.length})</h2>');

      final issuesByFile = <String, List<Issue>>{};
      for (final issue in result.issues) {
        issuesByFile.putIfAbsent(issue.filePath, () => []).add(issue);
      }

      for (final entry in issuesByFile.entries) {
        buffer.writeln('<div class="file-group">');
        buffer.writeln(
            '<h3>📄 ${_escapeHtml(entry.key)} <span class="badge">${entry.value.length}</span></h3>');
        buffer.writeln('<table class="issues-table">');
        buffer.writeln('<thead><tr>');
        buffer.writeln('<th>${isEn ? 'Sev.' : 'Sev.'}</th>');
        buffer.writeln('<th>${isEn ? 'Category' : 'Kategori'}</th>');
        buffer.writeln('<th>${isEn ? 'Rule' : 'Kural'}</th>');
        buffer.writeln('<th>${isEn ? 'Line' : 'Satır'}</th>');
        buffer.writeln('<th>${isEn ? 'Message' : 'Mesaj'}</th>');
        buffer.writeln('<th>${isEn ? 'Suggestion' : 'Öneri'}</th>');
        buffer.writeln('</tr></thead>');
        buffer.writeln('<tbody>');

        entry.value.sort((a, b) => a.severity.index.compareTo(b.severity.index));
        for (final issue in entry.value) {
          buffer.writeln(
              '<tr class="severity-${issue.severity.name}" data-severity="${issue.severity.name}">');
          buffer.writeln(
            '<td><span class="severity-badge ${issue.severity.name}">${issue.severityLabel}</span></td>',
          );
          buffer.writeln('<td>${_escapeHtml(_categoryTitle(issue.category, isEn))}</td>');
          buffer.writeln('<td><code>${_escapeHtml(issue.ruleId)}</code></td>');
          buffer.writeln('<td>${issue.line}${issue.column > 0 ? ':${issue.column}' : ''}</td>');
          buffer.writeln('<td>${_escapeHtml(issue.message)}</td>');
          buffer.writeln(
            '<td>${issue.suggestion != null ? _escapeHtml(issue.suggestion!) : "—"}</td>',
          );
          buffer.writeln('</tr>');
        }

        buffer.writeln('</tbody></table>');
        buffer.writeln('</div>');
      }
      buffer.writeln('</section>');
    } else {
      buffer.writeln('<section class="no-issues">');
      buffer.writeln(isEn
          ? '<h2>✅ No issues in this run.</h2>'
          : '<h2>✅ Bu çalıştırmada sorun yok.</h2>');
      buffer.writeln('</section>');
    }

    buffer.writeln('<script>');
    buffer.writeln(_getScript());
    buffer.writeln('</script>');

    buffer.writeln(
        '<footer>Flutter Deep Analyzer $_packageVersion · ${isEn ? 'Static analysis report (no quick-fix)' : 'Statik analiz raporu (quick-fix yok)'}</footer>');
    buffer.writeln('</div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  String _scaleExplanation(int files, bool isEn) {
    if (files <= ProjectScorer.referansDosyaSayısı) {
      return isEn
          ? 'Scoring uses full penalty weights for this codebase size (≤ ${ProjectScorer.referansDosyaSayısı} scanned files).'
          : 'Puanlama bu kod tabanı boyutunda tam ceza ağırlıkları kullanır (≤ ${ProjectScorer.referansDosyaSayısı} taranan dosya).';
    }
    return isEn
        ? 'Large-project scaling active: penalties are scaled by √(ref/n) with ref=${ProjectScorer.referansDosyaSayısı} so scores reflect density, not raw volume alone.'
        : 'Büyük proje ölçeklemesi açık: cezalar √(ref/n) ile düşürülür (ref=${ProjectScorer.referansDosyaSayısı}); skor yalnızca ham sayıya değil yoğunluğa yakınsar.';
  }

  String _legendRow(String label, int count, String color) {
    return '<div class="legend-row"><span class="legend-swatch" style="background:$color"></span>'
        '<span class="legend-label">$label</span><span class="legend-count">$count</span></div>';
  }

  void _writeMetricTile(StringBuffer buffer, String title, String value, String subtitle) {
    buffer.writeln('<div class="metric-tile">');
    buffer.writeln('<div class="metric-value">$value</div>');
    buffer.writeln('<div class="metric-title">$title</div>');
    buffer.writeln('<div class="metric-sub">$subtitle</div>');
    buffer.writeln('</div>');
  }

  String _donutGradient(AnalysisResult result) {
    final t = result.issues.length;
    if (t == 0) return 'conic-gradient(from -90deg, #334155 0deg 360deg)';
    var angle = -90.0;
    final parts = <String>[];

    void add(double count, String color) {
      if (count <= 0) return;
      final sweep = count / t * 360;
      final end = angle + sweep;
      parts.add('$color ${angle}deg ${end}deg');
      angle = end;
    }

    add(result.errorCount.toDouble(), '#ef4444');
    add(result.warningCount.toDouble(), '#eab308');
    add(result.infoCount.toDouble(), '#3b82f6');
    add(result.styleCount.toDouble(), '#94a3b8');

    if (parts.isEmpty) return 'conic-gradient(from -90deg, #334155 0deg 360deg)';
    return 'conic-gradient(from -90deg, ${parts.join(', ')})';
  }

  String _categoryTitle(IssueCategory c, bool isEn) {
    if (!isEn) {
      switch (c) {
        case IssueCategory.architecture:
          return 'Mimari';
        case IssueCategory.codeQuality:
          return 'Kod kalitesi';
        case IssueCategory.bestPractice:
          return 'Best practice';
        case IssueCategory.security:
          return 'Güvenlik';
        case IssueCategory.raceCondition:
          return 'Race condition';
        case IssueCategory.performance:
          return 'Performans';
        case IssueCategory.memoryLeak:
          return 'Bellek sızıntısı';
        case IssueCategory.typeSafety:
          return 'Tip güvenliği';
      }
    }
    switch (c) {
      case IssueCategory.architecture:
        return 'Architecture';
      case IssueCategory.codeQuality:
        return 'Code quality';
      case IssueCategory.bestPractice:
        return 'Best practices';
      case IssueCategory.security:
        return 'Security';
      case IssueCategory.raceCondition:
        return 'Race conditions';
      case IssueCategory.performance:
        return 'Performance';
      case IssueCategory.memoryLeak:
        return 'Memory leaks';
      case IssueCategory.typeSafety:
        return 'Type safety';
    }
  }

  void _writeSummaryCard(StringBuffer buffer, String label, String value, String type,
      {bool filterable = false}) {
    final filterAttr = filterable ? ' data-filter="$type" onclick="toggleFilter(\'$type\')"' : '';
    final cursorStyle = filterable ? ' style="cursor:pointer"' : '';
    buffer.writeln('<div class="summary-card $type"$filterAttr$cursorStyle>');
    buffer.writeln('<div class="card-value">$value</div>');
    buffer.writeln('<div class="card-label">$label</div>');
    buffer.writeln('</div>');
  }

  void _writeCategoryCard(StringBuffer buffer, CategoryScore cat, bool isEn) {
    final title = _categoryTitle(cat.category, isEn);
    buffer.writeln('<div class="category-card grade-${cat.grade.toLowerCase()}">');
    buffer.writeln('<div class="cat-header">');
    buffer.writeln('<span class="cat-name">${cat.gradeEmoji} $title</span>');
    buffer.writeln('<span class="cat-grade">${cat.grade}</span>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="progress-bar">');
    buffer.writeln('<div class="progress-fill" style="width: ${cat.score}%"></div>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="cat-score">${cat.score.toStringAsFixed(1)}/100</div>');
    buffer.writeln('<div class="cat-details">');
    buffer.writeln(isEn
        ? 'E ${cat.errorCount} · W ${cat.warningCount} · I ${cat.infoCount} · S ${cat.styleCount}'
        : 'E ${cat.errorCount} · W ${cat.warningCount} · I ${cat.infoCount} · S ${cat.styleCount}');
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
  background: #0b1220; color: #e2e8f0; line-height: 1.55;
}
.container { max-width: 1280px; margin: 0 auto; padding: 2rem 1.5rem 3rem; }
.report-nav {
  display: flex; flex-wrap: wrap; gap: 0.75rem 1.25rem;
  padding: 0.75rem 1rem; margin-bottom: 1.5rem;
  background: #111827; border: 1px solid #1f2937; border-radius: 10px;
  position: sticky; top: 0; z-index: 10;
}
.report-nav a { color: #38bdf8; text-decoration: none; font-size: 0.9rem; }
.report-nav a:hover { text-decoration: underline; }

header { margin-bottom: 1.5rem; }
header h1 {
  font-size: 1.85rem;
  background: linear-gradient(135deg, #38bdf8, #a78bfa);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
}
.timestamp, .path { color: #64748b; font-size: 0.9rem; }
.hint, .scale-hint { color: #94a3b8; font-size: 0.82rem; margin-top: 0.35rem; max-width: 52rem; }
.scale-hint { border-left: 3px solid #334155; padding-left: 0.75rem; margin-top: 0.6rem; }

.score-section { display: flex; flex-direction: column; align-items: center; gap: 2rem; margin-bottom: 2rem; }
.overall-score {
  width: 176px; height: 176px; border-radius: 50%;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  border: 4px solid; position: relative;
}
.grade-a { border-color: #22c55e; }
.grade-b { border-color: #3b82f6; }
.grade-c { border-color: #eab308; }
.grade-d { border-color: #f97316; }
.grade-f { border-color: #ef4444; }
.score-value { font-size: 2.45rem; font-weight: bold; }
.score-grade { font-size: 1.45rem; font-weight: bold; }
.score-label { font-size: 0.78rem; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.06em; }

.summary-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(112px, 1fr)); gap: 0.85rem; width: 100%; }
.summary-card {
  background: #111827; border-radius: 12px; padding: 0.85rem 0.65rem; text-align: center;
  border: 1px solid #1f2937; transition: transform 0.2s, box-shadow 0.2s;
}
.summary-card:hover { transform: translateY(-2px); }
.summary-card[data-filter] { cursor: pointer; }
.summary-card.active-filter { box-shadow: 0 0 0 2px #38bdf8; border-color: #38bdf8; transform: translateY(-3px); }
.summary-card.active-filter.error { box-shadow: 0 0 0 2px #ef4444; border-color: #ef4444; }
.summary-card.active-filter.warning { box-shadow: 0 0 0 2px #eab308; border-color: #eab308; }
.summary-card.active-filter.info { box-shadow: 0 0 0 2px #3b82f6; border-color: #3b82f6; }
.summary-card.active-filter.style { box-shadow: 0 0 0 2px #94a3b8; border-color: #94a3b8; }
.issue-row-hidden { display: none !important; }
.file-group-hidden { display: none !important; }
.card-value { font-size: 1.65rem; font-weight: bold; }
.card-label { font-size: 0.78rem; color: #94a3b8; }
.summary-card.error .card-value { color: #ef4444; }
.summary-card.warning .card-value { color: #eab308; }
.summary-card.info .card-value { color: #3b82f6; }

.panel { margin-bottom: 2.25rem; }
.panel h2 { font-size: 1.25rem; margin-bottom: 0.75rem; }
.panel-desc { color: #94a3b8; font-size: 0.85rem; margin-bottom: 1rem; max-width: 48rem; }

.metric-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
}
.metric-tile {
  background: #111827; border: 1px solid #1f2937; border-radius: 12px;
  padding: 1.1rem 1rem;
}
.metric-value { font-size: 1.75rem; font-weight: 700; color: #f1f5f9; }
.metric-title { font-size: 0.88rem; color: #cbd5e1; margin-top: 0.35rem; }
.metric-sub { font-size: 0.75rem; color: #64748b; margin-top: 0.25rem; }

.categories-section { margin-bottom: 2rem; }
.categories-section > h2 { font-size: 1.35rem; margin-bottom: 1rem; }
.subhead { font-size: 1rem; color: #94a3b8; margin: 1.25rem 0 0.75rem; font-weight: 600; }

.two-col {
  display: grid;
  grid-template-columns: minmax(200px, 240px) 1fr;
  gap: 2rem; align-items: center;
  margin-bottom: 1.5rem;
}
@media (max-width: 720px) {
  .two-col { grid-template-columns: 1fr; justify-items: center; }
}

.donut-wrap {
  position: relative; width: 200px; height: 200px;
}
.donut {
  width: 200px; height: 200px; border-radius: 50%;
}
.donut-hole {
  position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%);
  width: 112px; height: 112px; border-radius: 50%; background: #0b1220;
  z-index: 1;
}
.donut-center {
  position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%);
  z-index: 2; font-size: 1.35rem; font-weight: 700; color: #f8fafc;
  pointer-events: none;
}
.legend { width: 100%; max-width: 420px; }
.legend-row {
  display: flex; align-items: center; gap: 0.6rem;
  padding: 0.35rem 0; font-size: 0.88rem;
}
.legend-swatch { width: 12px; height: 12px; border-radius: 3px; flex-shrink: 0; }
.legend-label { flex: 1; color: #cbd5e1; }
.legend-count { font-weight: 600; color: #f1f5f9; }

.category-bars { margin-bottom: 1.75rem; }
.cat-bar-row {
  display: grid;
  grid-template-columns: minmax(120px, 200px) 1fr 48px;
  gap: 0.75rem; align-items: center; margin-bottom: 0.5rem; font-size: 0.88rem;
}
.cat-bar-label { color: #cbd5e1; }
.cat-bar-track {
  height: 10px; background: #1f2937; border-radius: 6px; overflow: hidden;
}
.cat-bar-fill {
  height: 100%; border-radius: 6px;
  background: linear-gradient(90deg, #38bdf8, #818cf8);
}
.cat-bar-count { text-align: right; font-weight: 600; color: #94a3b8; }
.empty-note { color: #64748b; font-size: 0.9rem; }

.category-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(248px, 1fr)); gap: 1rem; margin-top: 1rem; }
.category-card {
  background: #111827; border-radius: 12px; padding: 1.15rem;
  border-left: 4px solid; transition: transform 0.2s;
  border: 1px solid #1f2937; border-left-width: 4px;
}
.category-card:hover { transform: translateY(-2px); }
.category-card.grade-a { border-left-color: #22c55e; }
.category-card.grade-b { border-left-color: #3b82f6; }
.category-card.grade-c { border-left-color: #eab308; }
.category-card.grade-d { border-left-color: #f97316; }
.category-card.grade-f { border-left-color: #ef4444; }
.cat-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; }
.cat-name { font-weight: 600; font-size: 0.92rem; }
.cat-grade { font-size: 1.15rem; font-weight: bold; }
.progress-bar { height: 6px; background: #1f2937; border-radius: 3px; overflow: hidden; margin-bottom: 0.45rem; }
.progress-fill { height: 100%; border-radius: 3px; transition: width 0.5s ease; }
.grade-a .progress-fill { background: #22c55e; }
.grade-b .progress-fill { background: #3b82f6; }
.grade-c .progress-fill { background: #eab308; }
.grade-d .progress-fill { background: #f97316; }
.grade-f .progress-fill { background: #ef4444; }
.cat-score { font-size: 0.88rem; color: #94a3b8; }
.cat-details { font-size: 0.78rem; color: #64748b; margin-top: 0.35rem; }

.table-scroll { overflow-x: auto; border-radius: 10px; border: 1px solid #1f2937; }
.data-table { width: 100%; border-collapse: collapse; font-size: 0.86rem; min-width: 480px; }
.data-table th {
  text-align: left; padding: 0.65rem 0.85rem; color: #94a3b8;
  background: #111827; border-bottom: 1px solid #1f2937; white-space: nowrap;
}
.data-table td { padding: 0.55rem 0.85rem; border-bottom: 1px solid #1a2234; }
.data-table tbody tr:hover { background: #111827; }
.rules-table td:last-child { font-variant-numeric: tabular-nums; }

.file-group { background: #111827; border-radius: 12px; padding: 1.15rem; margin-bottom: 1rem; border: 1px solid #1f2937; }
.file-group h3 { font-size: 0.98rem; margin-bottom: 0.85rem; color: #38bdf8; word-break: break-all; }
.badge {
  background: #1f2937; color: #94a3b8; padding: 2px 8px; border-radius: 10px;
  font-size: 0.72rem; font-weight: normal;
}

.issues-table { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
.issues-table th { text-align: left; padding: 0.55rem 0.45rem; color: #64748b; border-bottom: 1px solid #1f2937; }
.issues-table td { padding: 0.55rem 0.45rem; border-bottom: 1px solid #1a2234; vertical-align: top; }
.issues-table tr:hover { background: #151f33; }

.severity-badge {
  padding: 2px 7px; border-radius: 4px; font-size: 0.72rem; font-weight: 600;
}
.severity-badge.error { background: rgba(239,68,68,0.18); color: #f87171; }
.severity-badge.warning { background: rgba(234,179,8,0.18); color: #fbbf24; }
.severity-badge.info { background: rgba(59,130,246,0.18); color: #60a5fa; }
.severity-badge.style { background: rgba(148,163,184,0.18); color: #cbd5e1; }

code { background: #1f2937; padding: 2px 6px; border-radius: 4px; font-size: 0.78rem; }

.no-issues { text-align: center; padding: 3rem; color: #22c55e; }

footer { text-align: center; color: #475569; font-size: 0.78rem; margin-top: 3rem; padding-top: 1.25rem; border-top: 1px solid #1f2937; }

@media (max-width: 768px) {
  .container { padding: 1rem; }
  .summary-cards { grid-template-columns: repeat(3, 1fr); }
  .category-grid { grid-template-columns: 1fr; }
  .cat-bar-row { grid-template-columns: 1fr; gap: 0.35rem; }
}
''';
  }

  String _getScript() {
    return '''
let activeFilter = null;

function toggleFilter(severity) {
  const cards = document.querySelectorAll('.summary-card[data-filter]');
  const rows = document.querySelectorAll('tr[data-severity]');
  const fileGroups = document.querySelectorAll('.file-group');

  if (activeFilter === severity) {
    activeFilter = null;
    cards.forEach(c => c.classList.remove('active-filter'));
    rows.forEach(r => r.classList.remove('issue-row-hidden'));
    fileGroups.forEach(fg => fg.classList.remove('file-group-hidden'));
    return;
  }

  activeFilter = severity;

  cards.forEach(c => {
    if (c.getAttribute('data-filter') === severity) {
      c.classList.add('active-filter');
    } else {
      c.classList.remove('active-filter');
    }
  });

  rows.forEach(r => {
    if (r.getAttribute('data-severity') === severity) {
      r.classList.remove('issue-row-hidden');
    } else {
      r.classList.add('issue-row-hidden');
    }
  });

  fileGroups.forEach(fg => {
    const visibleRows = fg.querySelectorAll('tr[data-severity]:not(.issue-row-hidden)');
    if (visibleRows.length === 0) {
      fg.classList.add('file-group-hidden');
    } else {
      fg.classList.remove('file-group-hidden');
    }
  });
}
''';
  }
}
