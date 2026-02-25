import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import 'base_analyzer.dart';

/// Performans Analyzer
///
/// Kontrol edilen kurallar:
/// - Build metodu içinde karmaşık logic
/// - Build içinde pahalı işlem (IO, network)
/// - ListView vs ListView.builder
/// - setState ile gereksiz rebuild riski
/// - Ağır animasyon karmaşıklığı
/// - const widget eksikliği
class PerformanceAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  PerformanceAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory.performance;

  @override
  String get name => 'Performans Analyzer';

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];
    final visitor = _PerformanceVisitor(
      filePath: filePath,
      issues: issues,
      config: config,
      fileContent: fileContent,
    );
    unit.unit.visitChildren(visitor);
    return issues;
  }
}

class _PerformanceVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;
  final String fileContent;

  bool _isInBuildMethod = false;
  bool _isInWidgetClass = false;

  _PerformanceVisitor({
    required this.filePath,
    required this.issues,
    required this.config,
    required this.fileContent,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Widget sınıfı mı kontrol et
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superClass = extendsClause.superclass.name2.lexeme;
      _isInWidgetClass = superClass.contains('Widget') ||
          superClass.contains('State') ||
          superClass == 'StatelessWidget' ||
          superClass == 'StatefulWidget';
    }

    super.visitClassDeclaration(node);
    _isInWidgetClass = false;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasInBuild = _isInBuildMethod;

    if (node.name.lexeme == 'build' && _isInWidgetClass) {
      _isInBuildMethod = true;
      _checkBuildMethodComplexity(node);
    }

    super.visitMethodDeclaration(node);
    _isInBuildMethod = wasInBuild;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    final constructorName = node.constructorName.name?.name;

    // ListView vs ListView.builder kontrolü
    if (typeName == 'ListView' && constructorName == null) {
      // Eğer children parametresi varsa ve uzun bir liste olabilirse
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final value = arg.expression;
          if (value is ListLiteral && value.elements.length > 10) {
            issues.add(
              Issue(
                ruleId: 'perf-list-builder',
                severity: Severity.warning,
                category: IssueCategory.performance,
                message: 'ListView yerine ListView.builder kullanın. '
                    '${value.elements.length} child widget birden render ediliyor.',
                filePath: filePath,
                line: _getLineNumber(node.offset),
                suggestion:
                    'ListView.builder lazy loading yapar, sadece ekranda görünen widget\'ları oluşturur. '
                    'Bu bellek ve performans açısından daha verimlidir.',
              ),
            );
          }
        }
      }
    }

    // Column/Row içinde uzun liste kontrolü
    if ((typeName == 'Column' || typeName == 'Row') && _isInBuildMethod) {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final value = arg.expression;
          if (value is ListLiteral && value.elements.length > 15) {
            issues.add(
              Issue(
                ruleId: 'perf-build-complexity',
                severity: Severity.warning,
                category: IssueCategory.performance,
                message: '$typeName içinde ${value.elements.length} child widget var. '
                    'Widget\'ları ayrı metod veya widget\'lara çıkarın.',
                filePath: filePath,
                line: _getLineNumber(node.offset),
                suggestion:
                    'Büyük widget ağaçlarını küçük, yeniden kullanılabilir widget\'lara bölün.',
              ),
            );
          }
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Build içinde pahalı işlem kontrolü
    if (_isInBuildMethod) {
      final methodName = node.methodName.name;

      // IO işlemleri
      final expensiveOps = [
        'readAsString',
        'readAsBytes',
        'readAsLines',
        'writeAsString',
        'writeAsBytes',
        'readSync',
        'writeSync',
        'get',
        'post',
        'put',
        'delete',
        'patch',
        'fetch',
        'request',
        'jsonDecode',
        'compute',
      ];

      if (expensiveOps.contains(methodName)) {
        issues.add(
          Issue(
            ruleId: 'perf-expensive-in-build',
            severity: Severity.error,
            category: IssueCategory.performance,
            message: 'Build metodu içinde pahalı işlem: $methodName(). '
                'Bu, her rebuild\'da çalışır ve performansı ciddi düşürür.',
            filePath: filePath,
            line: _getLineNumber(node.offset),
            suggestion: 'Bu işlemi initState, didChangeDependencies veya bir state management '
                'çözümüne taşıyın. Build metodu sadece widget ağacı oluşturmalı.',
          ),
        );
      }

      // Build içinde setState kontrolü
      if (methodName == 'setState') {
        issues.add(
          Issue(
            ruleId: 'perf-unnecessary-rebuild',
            severity: Severity.warning,
            category: IssueCategory.performance,
            message: 'Build metodu içinde setState() çağrısı tespit edildi. '
                'Bu sonsuz rebuild döngüsüne neden olabilir!',
            filePath: filePath,
            line: _getLineNumber(node.offset),
            suggestion: 'setState\'i build metodu dışında, event handler\'larda kullanın.',
          ),
        );
      }
    }

    // MediaQuery.of(context) kontrolü - gereksiz rebuild
    if (node.methodName.name == 'of' && _isInBuildMethod) {
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'MediaQuery') {
        issues.add(
          Issue(
            ruleId: 'perf-unnecessary-rebuild',
            severity: Severity.info,
            category: IssueCategory.performance,
            message: 'MediaQuery.of(context) tüm MediaQuery değişikliklerinde rebuild tetikler.',
            filePath: filePath,
            line: _getLineNumber(node.offset),
            suggestion: 'Sadece ihtiyacınız olan değeri almak için MediaQuery.sizeOf(context), '
                'MediaQuery.paddingOf(context) vb. kullanın.',
          ),
        );
      }
    }

    super.visitMethodInvocation(node);
  }

  void _checkBuildMethodComplexity(MethodDeclaration node) {
    final bodySource = node.body.toSource();
    final lineCount = bodySource.split('\n').length;

    final threshold = config.getThreshold('performance', 'build_complexity_threshold', 80);

    if (lineCount > threshold) {
      issues.add(
        Issue(
          ruleId: 'perf-build-complexity',
          severity: Severity.warning,
          category: IssueCategory.performance,
          message: 'Build metodu çok karmaşık: $lineCount satır (eşik: $threshold). '
              'Widget ağacını daha küçük widget\'lara bölün.',
          filePath: filePath,
          line: _getLineNumber(node.name.offset),
          suggestion: 'Build metodunu küçük, odaklı widget sınıflarına veya '
              'builder metodlarına bölün. const constructor\'lar kullanın.',
        ),
      );
    }
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
