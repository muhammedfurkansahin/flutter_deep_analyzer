import 'dart:io';
import 'package:yaml/yaml.dart';

/// Analyzer konfigürasyon yöneticisi.
///
/// `analysis_options.yaml` içindeki `flutter_deep_analyzer` bölümünü okur.
class AnalyzerConfig {
  final Map<String, CategoryConfig> categories;
  final List<String> excludePatterns;
  final String? outputFormat;
  final String? outputPath;

  const AnalyzerConfig({
    required this.categories,
    this.excludePatterns = const [],
    this.outputFormat,
    this.outputPath,
  });

  /// Varsayılan konfigürasyon.
  factory AnalyzerConfig.defaults() {
    return AnalyzerConfig(
      categories: {
        'architecture': CategoryConfig.defaults(),
        'code_quality': CategoryConfig.defaults(),
        'best_practice': CategoryConfig.defaults(),
        'security': CategoryConfig.defaults(),
        'race_condition': CategoryConfig.defaults(),
        'performance': CategoryConfig.defaults(),
        'memory_leak': CategoryConfig.defaults(),
      },
      excludePatterns: ['**/*.g.dart', '**/*.freezed.dart', '**/generated/**', '**/.dart_tool/**'],
    );
  }

  /// YAML dosyasından konfigürasyon yükle.
  factory AnalyzerConfig.fromYamlFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return AnalyzerConfig.defaults();
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content);

    if (yaml is! YamlMap) {
      return AnalyzerConfig.defaults();
    }

    final deepAnalyzerConfig = yaml['flutter_deep_analyzer'];
    if (deepAnalyzerConfig is! YamlMap) {
      return AnalyzerConfig.defaults();
    }

    return AnalyzerConfig._fromYamlMap(deepAnalyzerConfig);
  }

  factory AnalyzerConfig._fromYamlMap(YamlMap map) {
    final categories = <String, CategoryConfig>{};
    final defaultCategories = [
      'architecture',
      'code_quality',
      'best_practice',
      'security',
      'race_condition',
      'performance',
      'memory_leak',
    ];

    final rulesMap = map['rules'] as YamlMap?;

    for (final cat in defaultCategories) {
      if (rulesMap != null && rulesMap[cat] is YamlMap) {
        categories[cat] = CategoryConfig.fromYamlMap(rulesMap[cat] as YamlMap);
      } else {
        categories[cat] = CategoryConfig.defaults();
      }
    }

    final excludeList = <String>[];
    final excludeYaml = map['exclude'];
    if (excludeYaml is YamlList) {
      for (final item in excludeYaml) {
        excludeList.add(item.toString());
      }
    } else {
      excludeList.addAll([
        '**/*.g.dart',
        '**/*.freezed.dart',
        '**/generated/**',
        '**/.dart_tool/**',
      ]);
    }

    return AnalyzerConfig(
      categories: categories,
      excludePatterns: excludeList,
      outputFormat: map['output_format']?.toString(),
      outputPath: map['output_path']?.toString(),
    );
  }

  /// Belirli bir kategori aktif mi?
  bool isCategoryEnabled(String key) {
    return categories[key]?.enabled ?? true;
  }

  /// Belirli bir kategori için eşik değeri al.
  int getThreshold(String categoryKey, String thresholdKey, int defaultValue) {
    return categories[categoryKey]?.thresholds[thresholdKey] ?? defaultValue;
  }
}

/// Kategori bazlı konfigürasyon.
class CategoryConfig {
  final bool enabled;
  final Map<String, int> thresholds;
  final Map<String, String> severityOverrides;

  const CategoryConfig({
    this.enabled = true,
    this.thresholds = const {},
    this.severityOverrides = const {},
  });

  factory CategoryConfig.defaults() => const CategoryConfig();

  factory CategoryConfig.fromYamlMap(YamlMap map) {
    final thresholds = <String, int>{};
    final severityOverrides = <String, String>{};

    map.forEach((key, value) {
      if (key == 'enabled' || key == 'severity_override') return;
      if (value is int) {
        thresholds[key.toString()] = value;
      }
    });

    final overrides = map['severity_override'];
    if (overrides is YamlMap) {
      overrides.forEach((key, value) {
        severityOverrides[key.toString()] = value.toString();
      });
    }

    return CategoryConfig(
      enabled: map['enabled'] as bool? ?? true,
      thresholds: thresholds,
      severityOverrides: severityOverrides,
    );
  }
}
