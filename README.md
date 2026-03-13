# Flutter Deep Analyzer 🔍

A comprehensive static analysis tool for Flutter and Dart projects. Analyzes architecture, code quality, best practices, security vulnerabilities, race conditions, performance issues, and memory leaks.

## Features

| Category | Description | Rules |
|----------|-------------|:-----:|
| 🏗️ **Architecture** | God class, layer purity, feature isolation, large file | 8 |
| 🛡️ **Type Safety** | strict-casts, strict-inference, strict-raw-types | 3 |
| 🔄 **State Mgmt** | Bloc public fields, Riverpod ref usage, GetX onClose | 3 |
| 📊 **Code Quality** | Cyclomatic complexity, long method, deep nesting | 6 |
| ✅ **Best Practice** | Naming convention, print usage, dynamic type | 7 |
| 🔒 **Security** | Hardcoded logic, XSS, insecure storage, async mounted | 9 |
| ♿ **Accessibility**| Missing semanticLabel, hardcoded strings | 2 |
| ⚡ **Race Condition** | Unawaited future, async setState, Completer misuse | 6 |
| 🚀 **Performance** | Build complexity, expensive ops, ListView.builder | 7 |
| 💧 **Memory Leak** | Controller/Stream/Timer dispose missing | 7 |

## Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_deep_analyzer:
    path: ./flutter_deep_analyzer  # Local usage
```

## Usage

### Basic Analysis

```bash
# Run interactive mode (asks for language, category, format, path)
dart run flutter_deep_analyzer analyze

# Full analysis on current directory
dart run flutter_deep_analyzer analyze .

# Security-only analysis
dart run flutter_deep_analyzer analyze --category=security .

# JSON report output
dart run flutter_deep_analyzer analyze --format=json --output=report.json .

# SonarQube report output (CI/CD)
dart run flutter_deep_analyzer analyze --format=sonarqube --output=gl-sast-report.json .

# HTML report output
dart run flutter_deep_analyzer analyze --format=html --output=report.html .

# Markdown report output
dart run flutter_deep_analyzer analyze --format=markdown --output=report.md .

### Baseline / Technical Debt Management

```bash
# Create a baseline to ignore existing issues in future runs
dart run flutter_deep_analyzer analyze --create-baseline .

# Run analysis avoiding previously baselined issues
dart run flutter_deep_analyzer analyze --use-baseline=baseline.json .
```

### Configuration

Add to your project's `analysis_options.yaml`:

```yaml
flutter_deep_analyzer:
  rules:
    architecture:
      god_class_threshold: 10
      max_inheritance_depth: 3
      max_file_lines: 300
      max_constructor_params: 7
    code_quality:
      cyclomatic_complexity_threshold: 10
      max_method_lines: 50
      max_nesting_depth: 4
    security:
      enabled: true
    performance:
      build_complexity_threshold: 80
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/generated/**"
```

## Scoring System

Each category and the overall project are scored from 0 to 100:

| Grade | Score Range | Meaning |
|-------|:---------:|---------|
| 🟢 A | 90-100 | Excellent |
| 🔵 B | 80-89 | Good |
| 🟡 C | 70-79 | Average |
| 🟠 D | 60-69 | Poor |
| 🔴 F | 0-59 | Critical |

**Penalty weights:** Error = -5, Warning = -2, Info = -0.5, Style = -0.25

## Output Formats

- **Console** — Colorful terminal output with emojis and progress bars
- **JSON** — Machine-readable for CI/CD integration
- **SonarQube** — DevOps & CI/CD Generic code quality data format importer
- **HTML** — Modern dark theme report viewable in browser
- **Markdown** — Visually rich format perfect for GitHub, GitLab, and IDEs

## Publishing to pub.dev

See the [Publishing](#publishing-to-pubdev) section below.

## License

MIT

---

# Flutter Deep Analyzer 🔍 (Türkçe)

Flutter ve Dart projeleri için kapsamlı statik analiz aracı. Mimari, kod kalitesi, best practice, güvenlik açıkları, race condition, performans ve bellek sızıntılarını analiz eder.

## Özellikler

| Kategori | Açıklama | Kural |
|----------|----------|:-----:|
| 🏗️ **Mimari** | God class, katman ihlali, özellik (feature) izolasyonu | 8 |
| 🛡️ **Tip Güvenliği** | strict-casts, strict-inference, strict-raw-types | 3 |
| 🔄 **State Mgmt** | Bloc public field, Riverpod alan kontrolü, GetX onClose | 3 |
| 📊 **Kod Kalitesi** | Cyclomatic complexity, uzun metod, derin nesting | 6 |
| ✅ **Best Practice** | İsimlendirme, documentation, print kullanımı, dynamic | 7 |
| 🔒 **Güvenlik** | Hardcoded secret, HTTP, XSS, insecure storage, async mounted | 9 |
| ♿ **Erişilebilirlik**| semanticLabel eksiği, hardcoded UI stringleri | 2 |
| ⚡ **Race Condition** | Unawaited future, async setState, Completer hatası | 6 |
| 🚀 **Performans** | Build complexity, expensive ops, ListView.builder | 7 |
| 💧 **Bellek Sızıntısı** | Controller/Stream/Timer dispose eksikliği | 7 |

## Kurulum

`pubspec.yaml` dosyanıza ekleyin:

```yaml
dev_dependencies:
  flutter_deep_analyzer:
    path: ./flutter_deep_analyzer  # Lokal kullanım
```

## Kullanım

```bash
# İnteraktif mod (Dil, Kategori, Format ve Dizin seçimi sorar)
dart run flutter_deep_analyzer analyze

# Tüm kategorilerde mevcut dizinde analiz
dart run flutter_deep_analyzer analyze .

# Sadece güvenlik analizi
dart run flutter_deep_analyzer analyze --category=security .

# JSON rapor çıktısı
dart run flutter_deep_analyzer analyze --format=json --output=report.json .

# SonarQube rapor çıktısı (CI/CD)
dart run flutter_deep_analyzer analyze --format=sonarqube --output=gl-sast-report.json .

# HTML rapor çıktısı
dart run flutter_deep_analyzer analyze --format=html --output=report.html .

# Markdown rapor çıktısı
dart run flutter_deep_analyzer analyze --format=markdown --output=report.md .

### Baseline / Teknik Borç Yönetimi

```bash
# Mevcut hataları baseline olarak belirleyip kaydetme
dart run flutter_deep_analyzer analyze --create-baseline .

# Baseline dosyasını kullanarak daha önce kaydedilen hataları yoksayma
dart run flutter_deep_analyzer analyze --use-baseline=baseline.json .
```

## Konfigürasyon

Projenizin `analysis_options.yaml` dosyasına ekleyin:

```yaml
flutter_deep_analyzer:
  rules:
    architecture:
      god_class_threshold: 10
      max_inheritance_depth: 3
      max_file_lines: 300
      max_constructor_params: 7
    code_quality:
      cyclomatic_complexity_threshold: 10
      max_method_lines: 50
      max_nesting_depth: 4
    security:
      enabled: true
    performance:
      build_complexity_threshold: 80
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/generated/**"
```

## Puanlama Sistemi

Her kategori ve genel proje 0-100 arası puanlanır:

| Not | Puan Aralığı | Anlamı |
|-----|:-----------:|--------|
| 🟢 A | 90-100 | Mükemmel |
| 🔵 B | 80-89 | İyi |
| 🟡 C | 70-79 | Orta |
| 🟠 D | 60-69 | Zayıf |
| 🔴 F | 0-59 | Kritik |

**Ceza ağırlıkları:** Error = -5, Warning = -2, Info = -0.5, Style = -0.25

## Çıktı Formatları

- **Console** — Renkli, emoji destekli terminal çıktısı
- **JSON** — CI/CD entegrasyonu için makine tarafından okunabilir
- **SonarQube** — DevOps sunucularına aktarılmak üzere entegre Sonar formatı
- **HTML** — Tarayıcıda açılabilir modern dark theme rapor
- **Markdown** — GitHub, GitLab ve IDE'lerde görüntülemek için çok uygun görsel format

---

