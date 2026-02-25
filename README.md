# Flutter Deep Analyzer 🔍

A comprehensive static analysis tool for Flutter and Dart projects. Analyzes architecture, code quality, best practices, security vulnerabilities, race conditions, performance issues, and memory leaks.

## Features

| Category | Description | Rules |
|----------|-------------|:-----:|
| 🏗️ **Architecture** | God class, layer violation, deep inheritance, large file | 6 |
| 📊 **Code Quality** | Cyclomatic complexity, long method, deep nesting, magic number | 6 |
| ✅ **Best Practice** | Naming convention, documentation, print usage, dynamic type | 7 |
| 🔒 **Security** | Hardcoded secret, HTTP, SQL injection, XSS, insecure storage | 8 |
| ⚡ **Race Condition** | Unawaited future, async setState, Completer misuse | 6 |
| 🚀 **Performance** | Build complexity, expensive ops, ListView.builder, MediaQuery | 7 |
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
# Full analysis
dart run flutter_deep_analyzer analyze .

# Security-only analysis
dart run flutter_deep_analyzer analyze --category=security .

# JSON report output
dart run flutter_deep_analyzer analyze --format=json --output=report.json .

# HTML report output
dart run flutter_deep_analyzer analyze --format=html --output=report.html .
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
- **HTML** — Modern dark theme report viewable in browser

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
| 🏗️ **Mimari** | God class, katman ihlali, derin inheritance, büyük dosya | 6 |
| 📊 **Kod Kalitesi** | Cyclomatic complexity, uzun metod, derin nesting, magic number | 6 |
| ✅ **Best Practice** | Naming convention, dökümantasyon, print kullanımı, dynamic | 7 |
| 🔒 **Güvenlik** | Hardcoded secret, HTTP, SQL injection, XSS, insecure storage | 8 |
| ⚡ **Race Condition** | Unawaited future, async setState, Completer misuse | 6 |
| 🚀 **Performans** | Build complexity, expensive ops, ListView.builder, MediaQuery | 7 |
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
# Tüm kategorilerde analiz
dart run flutter_deep_analyzer analyze .

# Sadece güvenlik analizi
dart run flutter_deep_analyzer analyze --category=security .

# JSON rapor çıktısı
dart run flutter_deep_analyzer analyze --format=json --output=report.json .

# HTML rapor çıktısı
dart run flutter_deep_analyzer analyze --format=html --output=report.html .
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
- **HTML** — Tarayıcıda açılabilir modern dark theme rapor

---

## pub.dev'e Yayınlama

### 1. Ön Hazırlık

```bash
# pubspec.yaml'ın doğru olduğundan emin olun
# Gerekli alanlar: name, version, description, repository, environment

# CHANGELOG.md oluşturun
touch CHANGELOG.md

# LICENSE dosyası oluşturun
touch LICENSE
```

### 2. pubspec.yaml Kontrol Listesi

`pubspec.yaml`'da şu alanların dolu olması gerekir:

```yaml
name: flutter_deep_analyzer
description: >
  A comprehensive static analysis tool for Flutter and Dart projects.
  Analyzes architecture, code quality, best practices, security,
  race conditions, performance, and memory leaks.
version: 0.1.0
repository: https://github.com/KULLANICI_ADINIZ/flutter_deep_analyzer
homepage: https://github.com/KULLANICI_ADINIZ/flutter_deep_analyzer
issue_tracker: https://github.com/KULLANICI_ADINIZ/flutter_deep_analyzer/issues
topics:
  - analyzer
  - linter
  - static-analysis
  - code-quality
  - flutter
```

### 3. Yayınlama Öncesi Kontrol

```bash
# Dry-run ile yayınlama simülasyonu (gerçekten yayınlamaz)
dart pub publish --dry-run
```

Bu komut şunları kontrol eder:
- `pubspec.yaml` geçerli mi
- `README.md` var mı
- `CHANGELOG.md` var mı
- `LICENSE` var mı
- Paket boyutu limitleri
- Bağımlılık sorunları

### 4. Google Hesabı ile Giriş

```bash
dart pub login
```

Tarayıcı açılır ve Google hesabınızla giriş yaparsınız.

### 5. Yayınla

```bash
dart pub publish
```

> ⚠️ **DİKKAT:** pub.dev'e yayınlanan paketler geri alınamaz! İlk yayından önce `--dry-run` ile kontrol edin.

### 6. Versiyon Güncelleme

Yeni versiyonlarda:
1. `pubspec.yaml`'da `version`'ı güncelleyin
2. `CHANGELOG.md`'ye değişiklikleri yazın
3. `dart pub publish` ile tekrar yayınlayın

### pub.dev Puan Kriterleri

pub.dev otomatik puan verir. Yüksek puan için:

- ✅ `README.md` detaylı olmalı
- ✅ `CHANGELOG.md` bulunmalı
- ✅ `LICENSE` dosyası olmalı
- ✅ Tüm public API'lar dökümante edilmeli (dartdoc)
- ✅ `dart analyze` sıfır hata
- ✅ `dart format` uygulanmış olmalı
- ✅ Platform desteği belirtilmeli
- ✅ `example/` klasörü ile örnek proje
