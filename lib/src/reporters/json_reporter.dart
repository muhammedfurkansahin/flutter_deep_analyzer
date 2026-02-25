import 'dart:convert';

import '../models/analysis_result.dart';
import '../models/score.dart';
import 'base_reporter.dart';

/// JSON formatında rapor üreten reporter.
/// CI/CD entegrasyonu için kullanılır.
class JsonReporter extends BaseReporter {
  @override
  String report(AnalysisResult result, ProjectScore score) {
    final json = {
      'flutter_deep_analyzer': {'version': '0.1.0', ...result.toJson(), 'score': score.toJson()},
    };

    return const JsonEncoder.withIndent('  ').convert(json);
  }
}
