import '../models/analysis_result.dart';
import '../models/score.dart';

/// Tüm reporter'ların türediği abstract sınıf.
abstract class BaseReporter {
  /// Analiz sonucunu raporla.
  String report(AnalysisResult result, ProjectScore score);
}
