import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';

/// Dart projesinin tip güvenliği konfigürasyonunu kontrol eden analizör.
/// `analysis_options.yaml` içinde strict modların açık olup olmadığını kontrol eder.
class TypeSafetyAnalyzer {
  final AnalyzerConfig config;

  TypeSafetyAnalyzer({required this.config});

  List<Issue> analyzeProject(String projectPath) {
    final issues = <Issue>[];
    final analysisOptionsFile = File(p.join(projectPath, 'analysis_options.yaml'));

    if (!analysisOptionsFile.existsSync()) {
      issues.add(
        Issue(
          ruleId: 'ts-missing-analysis-options',
          severity: Severity.warning,
          category: IssueCategory.typeSafety,
          message:
              'Projende analysis_options.yaml dosyası bulunamadı. Tip güvenliği kuralları uygulanamıyor.',
          filePath: 'analysis_options.yaml',
          line: 1,
          suggestion: 'Proje kök dizininde bir analysis_options.yaml dosyası oluşturun.',
        ),
      );
      return issues;
    }

    try {
      final yamlContent = analysisOptionsFile.readAsStringSync();
      final yaml = loadYaml(yamlContent);

      if (yaml is YamlMap) {
        final analyzerNode = yaml['analyzer'];
        if (analyzerNode is! YamlMap || analyzerNode['language'] is! YamlMap) {
          _reportMissingStrictModes(issues, 'analysis_options.yaml');
        } else {
          final languageMap = analyzerNode['language'] as YamlMap;
          if (languageMap['strict-casts'] != true) {
            _reportStrictMode(issues, 'strict-casts');
          }
          if (languageMap['strict-inference'] != true) {
            _reportStrictMode(issues, 'strict-inference');
          }
          if (languageMap['strict-raw-types'] != true) {
            _reportStrictMode(issues, 'strict-raw-types');
          }
        }
      } else {
        _reportMissingStrictModes(issues, 'analysis_options.yaml');
      }
    } catch (e) {
      issues.add(
        Issue(
          ruleId: 'ts-parse-error',
          severity: Severity.error,
          category: IssueCategory.typeSafety,
          message: 'analysis_options.yaml dosyası okunamadı veya parse edilemedi.',
          filePath: 'analysis_options.yaml',
          line: 1,
        ),
      );
    }

    return issues;
  }

  void _reportMissingStrictModes(List<Issue> issues, String filePath) {
    issues.add(
      Issue(
        ruleId: 'ts-strict-modes',
        severity: Severity.warning,
        category: IssueCategory.typeSafety,
        message:
            'Dart analyzer katı modları (strict-casts, strict-inference, strict-raw-types) yapılandırılmamış.',
        filePath: filePath,
        line: 1,
        suggestion: 'analyzer -> language altında katı modları true olarak ayarlayın.',
      ),
    );
  }

  void _reportStrictMode(List<Issue> issues, String mode) {
    issues.add(
      Issue(
        ruleId: 'ts-$mode',
        severity: Severity.warning,
        category: IssueCategory.typeSafety,
        message: "'\$mode' özelliği aktif değil. Kodun tip güvenliğini tehlikeye atar.",
        filePath: 'analysis_options.yaml',
        line: 1,
        suggestion: "analyzer: \n  language: \n    \$mode: true\nşeklinde ekleyin.",
      ),
    );
  }
}
