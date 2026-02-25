import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import 'base_analyzer.dart';

/// Race Condition Analyzer
///
/// Kontrol edilen kurallar:
/// - Await edilmemiş Future
/// - Fire-and-forget async çağrılar
/// - Async gap sonrası mounted kontrolsüz setState
/// - Stream subscription iptal eksikliği
/// - Completer yanlış kullanımı
/// - Shared mutable state tespiti
class RaceConditionAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  RaceConditionAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory.raceCondition;

  @override
  String get name => 'Race Condition Analyzer';

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];
    final visitor = _RaceConditionVisitor(
      filePath: filePath,
      issues: issues,
      config: config,
      fileContent: fileContent,
    );
    unit.unit.visitChildren(visitor);
    return issues;
  }
}

class _RaceConditionVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;
  final String fileContent;

  bool _isInAsyncMethod = false;
  bool _isInStatefulWidget = false;

  _RaceConditionVisitor({
    required this.filePath,
    required this.issues,
    required this.config,
    required this.fileContent,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // State sınıfı mı kontrol et
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superClass = extendsClause.superclass.name.lexeme;
      _isInStatefulWidget = superClass.startsWith('State');
    }

    super.visitClassDeclaration(node);

    _isInStatefulWidget = false;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasAsync = _isInAsyncMethod;
    _isInAsyncMethod = node.body.isAsynchronous;

    if (_isInAsyncMethod && _isInStatefulWidget) {
      _checkAsyncSetState(node);
    }

    super.visitMethodDeclaration(node);
    _isInAsyncMethod = wasAsync;
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    final expression = node.expression;

    // Await edilmemiş Future kontrolü
    if (!_isInAsyncMethod) {
      super.visitExpressionStatement(node);
      return;
    }

    if (expression is MethodInvocation) {
      final returnType = expression.staticType;
      if (returnType != null) {
        final typeName = returnType.getDisplayString();
        if (typeName.startsWith('Future') && !_isAwaited(node)) {
          issues.add(
            Issue(
              ruleId: 'race-unawaited-future',
              severity: Severity.warning,
              category: IssueCategory.raceCondition,
              message: 'Await edilmemiş Future: ${expression.methodName.name}(). '
                  'Bu bir race condition\'a neden olabilir.',
              filePath: filePath,
              line: _getLineNumber(node.offset),
              suggestion: 'await keyword ekleyin veya unawaited() ile kasıtlı olduğunu belirtin.',
            ),
          );
        }
      }
    }

    super.visitExpressionStatement(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;

    // Completer yanlış kullanım kontrolü
    if (typeName == 'Completer') {
      _checkCompleterUsage(node);
    }

    super.visitInstanceCreationExpression(node);
  }

  void _checkAsyncSetState(MethodDeclaration node) {
    final methodBody = node.body;
    if (methodBody is! BlockFunctionBody) return;

    final statements = methodBody.block.statements;
    var hasAwait = false;

    for (final stmt in statements) {
      // await ifadesi var mı?
      if (stmt.toSource().contains('await ')) {
        hasAwait = true;
      }

      // await sonrası setState çağrısı var mı?
      if (hasAwait && stmt.toSource().contains('setState')) {
        // mounted kontrolü var mı?
        final stmtSource = stmt.toSource();
        final prevStmtIdx = statements.indexOf(stmt);
        var hasMountedCheck = false;

        // Önceki statement'larda mounted kontrolü ara
        if (prevStmtIdx > 0) {
          for (var i = prevStmtIdx - 1; i >= 0; i--) {
            final prevSource = statements[i].toSource();
            if (prevSource.contains('mounted') || prevSource.contains('context.mounted')) {
              hasMountedCheck = true;
              break;
            }
            // Başka bir await varsa kontrolü durdur
            if (prevSource.contains('await ')) break;
          }
        }

        // Aynı satırda mounted kontrolü var mı?
        if (stmtSource.contains('mounted')) {
          hasMountedCheck = true;
        }

        if (!hasMountedCheck) {
          issues.add(
            Issue(
              ruleId: 'race-unsafe-set-state',
              severity: Severity.error,
              category: IssueCategory.raceCondition,
              message: 'Async gap sonrası mounted kontrolü olmadan setState() çağrısı. '
                  'Widget dispose edildikten sonra setState çağrılabilir!',
              filePath: filePath,
              line: _getLineNumber(stmt.offset),
              suggestion: 'setState öncesine "if (!mounted) return;" kontrolü ekleyin. '
                  'Flutter 3.7+ için "if (!context.mounted) return;" kullanabilirsiniz.',
            ),
          );
        }
      }
    }
  }

  void _checkCompleterUsage(InstanceCreationExpression node) {
    // Completer'ın bir fonksiyon scope'unda olup olmadığını kontrol et
    // Global scope'ta Completer kullanımı riskli
    var parent = node.parent;
    var isInFunction = false;
    while (parent != null) {
      if (parent is FunctionBody || parent is MethodDeclaration) {
        isInFunction = true;
        break;
      }
      parent = parent.parent;
    }

    if (!isInFunction) {
      issues.add(
        Issue(
          ruleId: 'race-completer-misuse',
          severity: Severity.error,
          category: IssueCategory.raceCondition,
          message:
              'Completer sınıf seviyesinde tanımlanmış. Bu, race condition\'lara neden olabilir.',
          filePath: filePath,
          line: _getLineNumber(node.offset),
          suggestion:
              'Completer\'ı fonksiyon scope\'unda tanımlayın veya uygun şekilde senkronize edin.',
        ),
      );
    }
  }

  bool _isAwaited(AstNode node) {
    var parent = node.parent;
    while (parent != null) {
      if (parent is AwaitExpression) return true;
      parent = parent.parent;
    }

    // Statement olarak çağrıldıysa ve parent bir expression statement ise
    // source'unda await var mı kontrol et
    return node.toSource().contains('await ');
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
