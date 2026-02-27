import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import '../utils/analyzer_utils.dart';
import 'base_analyzer.dart';

/// Best Practice Analyzer
///
/// Kontrol edilen kurallar:
/// - Global mutable değişkenler
/// - Public API dökümantasyon eksikliği
/// - print() kullanımı
/// - Gereksiz dynamic kullanımı
/// - İsimlendirme kuralları
/// - final eksikliği (basitleştirilmiş)
class BestPracticeAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  BestPracticeAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory.bestPractice;

  @override
  String get name => 'Best Practice Analyzer';

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];
    final visitor = _BestPracticeVisitor(
      filePath: filePath,
      issues: issues,
      config: config,
      fileContent: fileContent,
    );
    unit.unit.visitChildren(visitor);

    // print() kullanımı satır bazlı kontrol
    _checkPrintUsage(fileContent, filePath, issues);

    return issues;
  }

  void _checkPrintUsage(String fileContent, String filePath, List<Issue> issues) {
    final lines = fileContent.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      // Yorum satırlarını yoksay
      if (line.startsWith('//') || line.startsWith('*') || line.startsWith('/*')) {
        continue;
      }

      // Test dosyalarını yoksay
      if (filePath.contains('_test.dart') || filePath.contains('/test/')) {
        continue;
      }

      if (RegExp(r'\bprint\s*\(').hasMatch(line) || RegExp(r'\bdebugPrint\s*\(').hasMatch(line)) {
        issues.add(
          Issue(
            ruleId: 'bp-avoid-print',
            severity: Severity.warning,
            category: IssueCategory.bestPractice,
            message: 'Production kodda print()/debugPrint() kullanımı. Logger kullanın.',
            filePath: filePath,
            line: i + 1,
            codeSnippet: line,
            suggestion: 'print() yerine bir Logger paketi (ör: logger, logging) kullanın. '
                'debug/release modlarına göre log seviyesi kontrol edilebilir.',
          ),
        );
      }
    }
  }
}

class _BestPracticeVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;
  final String fileContent;

  _BestPracticeVisitor({
    required this.filePath,
    required this.issues,
    required this.config,
    required this.fileContent,
  });

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      // Global mutable değişken kontrolü
      if (!variable.isConst && !variable.isFinal) {
        issues.add(
          Issue(
            ruleId: 'bp-mutable-global',
            severity: Severity.warning,
            category: IssueCategory.bestPractice,
            message: 'Global mutable değişken: "${variable.nodeName}". '
                'Global state yönetimi sorunlara yol açabilir.',
            filePath: filePath,
            line: _getLineNumber(variable.name.offset),
            suggestion: 'Global değişkeni final/const yapın veya bir state management '
                'çözümü kullanın (Riverpod, Bloc, vb.).',
          ),
        );
      }
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Public class dökümantasyon kontrolü
    // ignore: deprecated_member_use
    final className = node.nodeName;
    if (!className.startsWith('_') && node.documentationComment == null) {
      issues.add(
        Issue(
          ruleId: 'bp-missing-doc',
          severity: Severity.info,
          category: IssueCategory.bestPractice,
          message: 'Public sınıf "$className" dökümantasyon yorumu içermiyor.',
          filePath: filePath,
          // ignore: deprecated_member_use
          line: _getLineNumber(node.name.offset),
          suggestion: '/// ile sınıfın amacını açıklayan bir dökümantasyon ekleyin.',
        ),
      );
    }

    // PascalCase isimlendirme kontrolü
    if (!_isPascalCase(className) && !className.startsWith('_')) {
      issues.add(
        Issue(
          ruleId: 'bp-naming-convention',
          severity: Severity.style,
          category: IssueCategory.bestPractice,
          message: 'Sınıf ismi "$className" PascalCase formatında olmalı.',
          filePath: filePath,
          // ignore: deprecated_member_use
          line: _getLineNumber(node.name.offset),
          suggestion: 'Sınıf isimlerini PascalCase ile yazın (ör: MyClassName).',
        ),
      );
    }

    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final methodName = node.nodeName;

    // Public method dökümantasyon kontrolü
    if (!methodName.startsWith('_') && node.documentationComment == null) {
      // getter/setter ve override hariç
      if (!node.isGetter && !node.isSetter) {
        final hasOverride = node.metadata.any((m) => m.name.name == 'override');
        if (!hasOverride) {
          issues.add(
            Issue(
              ruleId: 'bp-missing-doc',
              severity: Severity.info,
              category: IssueCategory.bestPractice,
              message: 'Public metod "$methodName" dökümantasyon yorumu içermiyor.',
              filePath: filePath,
              line: _getLineNumber(node.name.offset),
              suggestion: '/// ile metodun ne yaptığını açıklayan bir dökümantasyon ekleyin.',
            ),
          );
        }
      }
    }

    // camelCase isimlendirme kontrolü
    if (!_isCamelCase(methodName) && !methodName.startsWith('_') && methodName != 'build') {
      issues.add(
        Issue(
          ruleId: 'bp-naming-convention',
          severity: Severity.style,
          category: IssueCategory.bestPractice,
          message: 'Metod ismi "$methodName" camelCase formatında olmalı.',
          filePath: filePath,
          line: _getLineNumber(node.name.offset),
          suggestion: 'Metod isimlerini camelCase ile yazın (ör: myMethodName).',
        ),
      );
    }

    super.visitMethodDeclaration(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    // dynamic parametre kontrolü
    final type = node.type;
    if (type != null && type.toSource() == 'dynamic') {
      issues.add(
        Issue(
          ruleId: 'bp-avoid-dynamic',
          severity: Severity.warning,
          category: IssueCategory.bestPractice,
          message:
              'Parametre "${node.nodeName.isEmpty ? 'unknown' : node.nodeName}" dynamic olarak tanımlanmış. '
              'Tip güvenliği için spesifik tip kullanın.',
          filePath: filePath,
          line: _getLineNumber(node.offset),
          suggestion:
              'dynamic yerine spesifik tip kullanın. Birden fazla tip mümkünse Object? kullanın.',
        ),
      );
    }
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // dynamic değişken kontrolü
    final parent = node.parent;
    if (parent is VariableDeclarationList) {
      final type = parent.type;
      if (type != null && type.toSource() == 'dynamic') {
        issues.add(
          Issue(
            ruleId: 'bp-avoid-dynamic',
            severity: Severity.warning,
            category: IssueCategory.bestPractice,
            message: 'Değişken "${node.nodeName}" dynamic olarak tanımlanmış. '
                'Tip güvenliği için spesifik tip kullanın.',
            filePath: filePath,
            line: _getLineNumber(node.name.offset),
            suggestion: 'dynamic yerine spesifik tip belirtin veya var kullanın.',
          ),
        );
      }
    }
    super.visitVariableDeclaration(node);
  }

  bool _isPascalCase(String name) {
    if (name.isEmpty) return false;
    return RegExp(r'^[A-Z][a-zA-Z0-9]*$').hasMatch(name);
  }

  bool _isCamelCase(String name) {
    if (name.isEmpty) return false;
    return RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(name);
  }

  int _getLineNumber(int offset) {
    final lines = fileContent.split('\n');
    var charCount = 0;
    for (var i = 0; i < lines.length; i++) {
      charCount += lines[i].length + 1;
      if (charCount > offset) return i + 1;
    }
    return 1;
  }
}
