import 'dart:convert';
import 'dart:io';

import 'issue.dart';

/// Baseline dosyası yönetim modülü.
/// Önceki analizlerden kalan teknik borçları kaydederek yeni analiz sonuçlarında filtreleme yapar.
class BaselineManager {
  final Map<String, String> _baselinedIssues = {};

  /// Geçerli Issues listesini baz alarak yeni bir baseline dosyası oluşturur.
  static Future<void> createBaseline(List<Issue> issues, String outputPath) async {
    final list = issues.map((i) => _generateHash(i)).toList();

    final file = File(outputPath);
    await file.writeAsString(jsonEncode({'baselined_issues': list}));
  }

  /// Mevcut baseline dosyasını yükler.
  Future<void> loadBaseline(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);

      if (data != null && data['baselined_issues'] is List) {
        for (final hash in data['baselined_issues']) {
          _baselinedIssues[hash.toString()] = hash.toString();
        }
      }
    } catch (e) {
      // Parse hatası vb. göz ardı edilebilir veya loglanabilir.
    }
  }

  /// Verilen Issue'nun baseline içinde olup olmadığını kontrol eder.
  bool contains(Issue issue) {
    return _baselinedIssues.containsKey(_generateHash(issue));
  }

  /// Mevcut analiz sonuçlarından baseline dahilindeki sorunları temizler.
  List<Issue> filterIssues(List<Issue> currentIssues) {
    if (_baselinedIssues.isEmpty) return currentIssues;

    return currentIssues.where((issue) => !contains(issue)).toList();
  }

  /// Bir Issue için kimlik (ID) oluşturur. Satır numarası değişmiş olabileceği için
  /// line hash içinde kullanılmaz, sadece kural, dosya ve mesaj kısmı kullanılır.
  /// Daha hassas bir yapı için context eklenebilir.
  static String _generateHash(Issue issue) {
    // Kategori, Kural ve Dosya adresi.
    return '${issue.ruleId}-${issue.filePath}-${issue.severity.name}';
  }
}
