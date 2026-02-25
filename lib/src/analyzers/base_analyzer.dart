import 'package:analyzer/dart/analysis/results.dart';
import '../models/issue.dart';

/// Tüm analizerlerin türediği abstract sınıf.
abstract class BaseAnalyzer {
  /// Bu analyzer'ın kategorisi.
  IssueCategory get category;

  /// Bu analyzer'ın adı.
  String get name;

  /// Bir Dart dosyasını analiz et ve Issue listesi döndür.
  ///
  /// [unit] - Resolved AST unit
  /// [filePath] - Dosya yolu
  /// [fileContent] - Dosya içeriği (satır bazlı kontroller için)
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent);
}
