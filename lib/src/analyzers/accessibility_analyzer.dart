import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import 'base_analyzer.dart';

/// Erişilebilirlik (A11y) Analyzer
///
/// Kontrol edilen kurallar:
/// - Ikonlarda semanticLabel olmaması
/// - Hardcoded string bulunması (Özellikle Text widgetları için)
class AccessibilityAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  AccessibilityAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory.codeQuality;

  @override
  String get name => 'Erişilebilirlik Analyzer';

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];

    if (!config.isCategoryEnabled('accessibility')) return issues;

    final visitor = _A11yVisitor(filePath: filePath, issues: issues, config: config);
    unit.unit.visitChildren(visitor);

    return issues;
  }
}

class _A11yVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;

  _A11yVisitor({required this.filePath, required this.issues, required this.config});

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();

    if (typeName == 'Icon') {
      final args = node.argumentList.arguments;
      final hasSemanticLabel =
          args.any((arg) => arg is NamedExpression && arg.name.label.name == 'semanticLabel');

      if (!hasSemanticLabel) {
        issues.add(
          Issue(
            ruleId: 'a11y-missing-semantic-label',
            severity: Severity.warning,
            category: IssueCategory.codeQuality,
            message:
                'Icon widget için semanticLabel tanımlanmamış. Ekran okuyucular için bu özellik zorunludur.',
            filePath: filePath,
            line: node.offset,
            suggestion: "Icon(..., semanticLabel: 'Açıklama') şeklinde semanticLabel ekleyin.",
          ),
        );
      }
    } else if (typeName == 'Text') {
      // Check hardcoded string
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final firstArg = args.first;
        if (firstArg is StringLiteral) {
          issues.add(
            Issue(
              ruleId: 'a11y-hardcoded-text-string',
              severity: Severity.style,
              category: IssueCategory.codeQuality,
              message: 'Text widget içerisinde sabit (hardcoded) metin kullanılmış.',
              filePath: filePath,
              line: node.offset,
              suggestion:
                  'Uluslararasılaştırma (L10n) için app_localizations veya benzeri bir yapı kullanarak metinleri ayırın.',
            ),
          );
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }
}
