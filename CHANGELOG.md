# Changelog



## 0.1.0

- Initial release
- 7 analyzer modules: Architecture, Code Quality, Best Practice, Security, Race Condition, Performance, Memory Leak
- 47 analysis rules
- Scoring system (0-100 with A-F grades)
- Console, JSON, and HTML report formats
- CLI with category filtering and configurable thresholds
- YAML-based configuration via `analysis_options.yaml`

## 1.0.0

- Initial release
- 7 analyzer modules: Architecture, Code Quality, Best Practice, Security, Race Condition, Performance, Memory Leak
- 47 analysis rules
- Scoring system (0-100 with A-F grades)
- Console, JSON, and HTML report formats
- CLI with category filtering and configurable thresholds
- YAML-based configuration via `analysis_options.yaml`

## 1.0.1

- Fix analyzer version

## 1.0.2

- Support backward compatibility for analyzer package (<10.0.0 and <=6.4.1) by handling getter access correctly (e.g. `node.name.lexeme` versus tokens/identifiers).
## 1.0.3
- CLI now features an interactive mode (asks for language, category, format, and path) when run without arguments, with bilingual prompts (English/Turkish).
- Added new Markdown report format (`--format=markdown`) alongside Console, JSON, and HTML.
- Always prints an overall score summary to terminal stderr even when generating JSON/HTML/Markdown.
## 1.0.4
- HTML report now includes interactive severity filters (Error, Warning, Info, Style) with visual feedback and smooth animations.

## 1.0.5

- **Baseline Support**: Added `--create-baseline` to save current technical debt and `--use-baseline=baseline.json` to ignore previously reported issues.
- **SonarQube Integration**: Added `--format=sonarqube` format for seamless CI/CD import to SonarQube servers.
- **Interactive CLI Expansion**: Included new feature parameters to the interactive cli setup sequence.
- **Type Safety Analyzer**: Validates `strict-casts`, `strict-inference` directly checking the `analysis_options.yaml` tree.
- **State Management Anti-patterns**: Detects unideal patterns in Bloc, Riverpod & GetX.
- **Accessibility & Security Rules**: Detects `semanticLabel` usage, checks `!mounted` returns for async blocks in BuildContext boundaries.

## 1.0.6

- **HTML raporu (DCM tarzı paneller)**: Üstte yapışkan bölüm gezintisi; şiddet dağılımı için donut grafik ve açıklama; kategori bazlı bulgu çubukları; taranan dosya başına bulgu, benzersiz kural sayısı ve toplam bulgu gibi yoğunluk metrikleri; ilk üç path segmentine göre gruplanan yoğun dizinler tablosu; en sık tetiklenen kurallar tablosu.
- **HTML özet modeli**: `html_report_aggregates.dart` ile kural/kategori/dizin bazlı istatistikler tek yerden hesaplanıyor.
- **HTML detayları**: Özet kartlarına etkilenen dosya sayısı; detaylı sorun tablosuna kategori sütunu, satır: sütun gösterimi ve kullanıcı girdisi için geliştirilmiş HTML kaçışı; quick-fix olmadığına dair TR/EN ipucu; büyük proje skor ölçeklemesi için raporda kısa açıklama metni.
- **Skorlama**: 40’tan fazla taranan dosyada toplam ceza `√(ref/n)` ile ölçeklenir (`ref = 40`); böylece çok dosyalı projelerde skor yoğunluğu yansıtır. `typeSafety` kategorisi için ek ağırlık (1.35) eklendi.
