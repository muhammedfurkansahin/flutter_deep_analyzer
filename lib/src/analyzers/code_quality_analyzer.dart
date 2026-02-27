import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import '../utils/analyzer_utils.dart';
import 'base_analyzer.dart';

/// Kod Kalitesi Analyzer
///
/// Kontrol edilen kurallar:
/// - Cyclomatic complexity
/// - Uzun metod tespiti
/// - Derin nesting
/// - Çok fazla metod
/// - Magic number
class CodeQualityAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  CodeQualityAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory.codeQuality;

  @override
  String get name => 'Kod Kalitesi Analyzer';

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];
    final visitor = _CodeQualityVisitor(
      filePath: filePath,
      issues: issues,
      config: config,
      fileContent: fileContent,
    );
    unit.unit.visitChildren(visitor);
    return issues;
  }
}

class _CodeQualityVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;
  final String fileContent;

  _CodeQualityVisitor({
    required this.filePath,
    required this.issues,
    required this.config,
    required this.fileContent,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // ignore: deprecated_member_use
    final className = node.nodeName;
    // ignore: deprecated_member_use
    final methods = node.members.whereType<MethodDeclaration>().toList();

    // Çok fazla metod kontrolü
    final maxMethods = config.getThreshold('code_quality', 'max_methods_per_class', 15);
    if (methods.length > maxMethods) {
      issues.add(
        Issue(
          ruleId: 'quality-too-many-methods',
          severity: Severity.info,
          category: IssueCategory.codeQuality,
          message:
              '"$className" sınıfında çok fazla metod var: ${methods.length} (eşik: $maxMethods).',
          filePath: filePath,
          // ignore: deprecated_member_use
          line: _getLineNumber(node.name.offset),
          suggestion: 'Sınıfı daha küçük, tek sorumluluklu sınıflara bölmeyi düşünün.',
        ),
      );
    }

    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _checkMethodComplexity(node.nodeName, node.body, node.name.offset);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _checkMethodComplexity(node.nodeName, node.functionExpression.body, node.name.offset);
    super.visitFunctionDeclaration(node);
  }

  void _checkMethodComplexity(String name, FunctionBody body, int offset) {
    // Uzun metod kontrolü
    final maxMethodLines = config.getThreshold('code_quality', 'max_method_lines', 50);
    final bodyText = body.toSource();
    final lineCount = bodyText.split('\n').length;
    if (lineCount > maxMethodLines) {
      issues.add(
        Issue(
          ruleId: 'quality-long-method',
          severity: Severity.warning,
          category: IssueCategory.codeQuality,
          message: '"$name" metodu çok uzun: $lineCount satır (eşik: $maxMethodLines).',
          filePath: filePath,
          line: _getLineNumber(offset),
          suggestion: 'Metodu daha küçük, iyi isimlendirilmiş yardımcı metodlara bölün.',
        ),
      );
    }

    // Cyclomatic complexity kontrolü
    final complexityThreshold = config.getThreshold(
      'code_quality',
      'cyclomatic_complexity_threshold',
      10,
    );
    final complexity = _calculateCyclomaticComplexity(body);
    if (complexity > complexityThreshold) {
      issues.add(
        Issue(
          ruleId: 'quality-cyclomatic-complexity',
          severity: Severity.warning,
          category: IssueCategory.codeQuality,
          message:
              '"$name" fonksiyonunun cyclomatic complexity\'si çok yüksek: $complexity (eşik: $complexityThreshold).',
          filePath: filePath,
          line: _getLineNumber(offset),
          suggestion: 'Koşulları sadeleştirin, guard clause kullanın veya stratejilere ayırın.',
        ),
      );
    }

    // Derin nesting kontrolü
    final maxNesting = config.getThreshold('code_quality', 'max_nesting_depth', 4);
    final nestingDepth = _calculateMaxNesting(body);
    if (nestingDepth > maxNesting) {
      issues.add(
        Issue(
          ruleId: 'quality-deep-nesting',
          severity: Severity.warning,
          category: IssueCategory.codeQuality,
          message:
              '"$name" fonksiyonunda derin iç içe yapı: $nestingDepth seviye (eşik: $maxNesting).',
          filePath: filePath,
          line: _getLineNumber(offset),
          suggestion: 'Early return, guard clause veya metod çıkarma ile iç içe yapıyı azaltın.',
        ),
      );
    }
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    final value = node.value;
    if (value == null) return;

    // 0, 1, 2 gibi yaygın değerleri yoksay
    if (value == 0 || value == 1 || value == 2 || value == -1) return;

    // Const tanımlamalar ve enum index'leri hariç
    final parent = node.parent;
    if (parent is VariableDeclaration) {
      if (parent.isConst) return;
      // final ile tanımlanan sabitler OK
      if (parent.isFinal) return;
    }
    if (parent is ConstructorFieldInitializer) return;
    if (parent is DefaultFormalParameter) return;
    if (parent is NamedExpression) return;

    issues.add(
      Issue(
        ruleId: 'quality-magic-number',
        severity: Severity.info,
        category: IssueCategory.codeQuality,
        message: 'Magic number tespit edildi: $value. Anlamlı bir sabit olarak tanımlayın.',
        filePath: filePath,
        line: _getLineNumber(node.offset),
        suggestion:
            'Bu değeri açıklayıcı isimli bir const ile değiştirin, ör: const maxRetryCount = $value;',
      ),
    );

    super.visitIntegerLiteral(node);
  }

  int _calculateCyclomaticComplexity(FunctionBody body) {
    final visitor = _ComplexityVisitor();
    body.accept(visitor);
    return visitor.complexity;
  }

  int _calculateMaxNesting(FunctionBody body) {
    final visitor = _NestingVisitor();
    body.accept(visitor);
    return visitor.maxDepth;
  }

  int _getLineNumber(int offset) {
    final lines = fileContent.split('\n');
    var charCount = 0;
    for (var i = 0; i < lines.length; i++) {
      charCount += lines[i].length + 1; // +1 for newline
      if (charCount > offset) return i + 1;
    }
    return 1;
  }
}

class _ComplexityVisitor extends RecursiveAstVisitor<void> {
  int complexity = 1; // Başlangıç değeri

  @override
  void visitIfStatement(IfStatement node) {
    complexity++;
    super.visitIfStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    complexity++;
    super.visitForStatement(node);
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    complexity++;
    super.visitForEachPartsWithDeclaration(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    complexity++;
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    complexity++;
    super.visitDoStatement(node);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    complexity++;
    super.visitSwitchCase(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    complexity++;
    super.visitCatchClause(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    complexity++;
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.lexeme == '&&' || node.operator.lexeme == '||') {
      complexity++;
    }
    super.visitBinaryExpression(node);
  }
}

class _NestingVisitor extends RecursiveAstVisitor<void> {
  int _currentDepth = 0;
  int maxDepth = 0;

  void _enter() {
    _currentDepth++;
    if (_currentDepth > maxDepth) maxDepth = _currentDepth;
  }

  void _exit() {
    _currentDepth--;
  }

  @override
  void visitIfStatement(IfStatement node) {
    _enter();
    super.visitIfStatement(node);
    _exit();
  }

  @override
  void visitForStatement(ForStatement node) {
    _enter();
    super.visitForStatement(node);
    _exit();
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _enter();
    super.visitWhileStatement(node);
    _exit();
  }

  @override
  void visitDoStatement(DoStatement node) {
    _enter();
    super.visitDoStatement(node);
    _exit();
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _enter();
    super.visitSwitchStatement(node);
    _exit();
  }

  @override
  void visitTryStatement(TryStatement node) {
    _enter();
    super.visitTryStatement(node);
    _exit();
  }
}
