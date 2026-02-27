import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import '../utils/analyzer_utils.dart';
import 'base_analyzer.dart';

/// Mimari Analyzer
///
/// Kontrol edilen kurallar:
/// - God class (çok fazla metod/alan)
/// - Derin inheritance zinciri
/// - Büyük dosya tespiti
/// - Constructor'da çok fazla parametre
/// - Katman ihlali tespiti
class ArchitectureAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  ArchitectureAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory.architecture;

  @override
  String get name => 'Mimari Analyzer';

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];
    final visitor = _ArchitectureVisitor(filePath: filePath, issues: issues, config: config);
    unit.unit.visitChildren(visitor);

    // Dosya boyutu kontrolü
    final maxLines = config.getThreshold('architecture', 'max_file_lines', 300);
    final lineCount = fileContent.split('\n').length;
    if (lineCount > maxLines) {
      issues.add(
        Issue(
          ruleId: 'arch-large-file',
          severity: Severity.info,
          category: IssueCategory.architecture,
          message:
              'Dosya çok büyük: $lineCount satır (eşik: $maxLines). Dosyayı daha küçük parçalara ayırmayı düşünün.',
          filePath: filePath,
          line: 1,
          suggestion: 'Dosyayı sorumluluk alanlarına göre daha küçük dosyalara bölün.',
        ),
      );
    }

    // Circular dependency kontrolü (import bazlı basit kontrol)
    _checkImports(unit.unit, filePath, issues);

    return issues;
  }

  void _checkImports(CompilationUnit unit, String filePath, List<Issue> issues) {
    final imports = <String>[];
    for (final directive in unit.directives) {
      if (directive is ImportDirective) {
        final uri = directive.uri.stringValue;
        if (uri != null) {
          imports.add(uri);
        }
      }
    }

    // Katman ihlali kontrolü: presentation katmanından data katmanına direkt erişim
    if (filePath.contains('/presentation/') ||
        filePath.contains('/ui/') ||
        filePath.contains('/pages/') ||
        filePath.contains('/screens/') ||
        filePath.contains('/widgets/')) {
      for (final importUri in imports) {
        if (importUri.contains('/data/') ||
            importUri.contains('/repository/') ||
            importUri.contains('/datasource/')) {
          final directive = unit.directives.firstWhere(
            (d) => d is ImportDirective && d.uri.stringValue == importUri,
            orElse: () => unit.directives.first,
          );
          issues.add(
            Issue(
              ruleId: 'arch-layer-violation',
              severity: Severity.error,
              category: IssueCategory.architecture,
              message:
                  'Katman ihlali: Presentation katmanı doğrudan data katmanına erişiyor. Import: $importUri',
              filePath: filePath,
              line: directive.offset,
              suggestion:
                  'Presentation katmanından data katmanına erişmek yerine domain/usecase katmanını kullanın.',
            ),
          );
        }
      }
    }
  }
}

class _ArchitectureVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;

  _ArchitectureVisitor({required this.filePath, required this.issues, required this.config});

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // ignore: deprecated_member_use
    final className = node.name.lexeme;
    // ignore: deprecated_member_use
    final methods = node.members.whereType<MethodDeclaration>().toList();
    // ignore: deprecated_member_use
    final fields = node.members.whereType<FieldDeclaration>().toList();

    // God class kontrolü
    final godClassThreshold = config.getThreshold('architecture', 'god_class_threshold', 10);
    if (methods.length > godClassThreshold) {
      issues.add(
        Issue(
          ruleId: 'arch-god-class',
          severity: Severity.warning,
          category: IssueCategory.architecture,
          message:
              '"$className" sınıfı God class olabilir: ${methods.length} metod (eşik: $godClassThreshold). '
              'Sınıfı daha küçük, tek sorumluluk ilkesine uygun sınıflara bölmeyi düşünün.',
          filePath: filePath,
          // ignore: deprecated_member_use
          line: node.name.offset,
          suggestion:
              'Single Responsibility Principle uygulayın. Sınıfı sorumluluk alanlarına göre bölün.',
        ),
      );
    }

    // Çok fazla alan kontrolü
    if (fields.length > 10) {
      issues.add(
        Issue(
          ruleId: 'arch-too-many-fields',
          severity: Severity.warning,
          category: IssueCategory.architecture,
          message: '"$className" sınıfında çok fazla alan var: ${fields.length}. '
              'Bu, sınıfın çok fazla sorumluluğa sahip olduğunu gösterebilir.',
          filePath: filePath,
          // ignore: deprecated_member_use
          line: node.name.offset,
          suggestion: 'İlişkili alanları ayrı sınıflara veya value object\'lere taşıyın.',
        ),
      );
    }

    // Constructor parametre sayısı kontrolü
    // ignore: deprecated_member_use
    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        final paramCount = member.parameters.parameters.length;
        final maxParams = config.getThreshold('architecture', 'max_constructor_params', 7);
        if (paramCount > maxParams) {
          issues.add(
            Issue(
              ruleId: 'arch-too-many-params',
              severity: Severity.warning,
              category: IssueCategory.architecture,
              message:
                  '"$className" constructor\'ında çok fazla parametre: $paramCount (eşik: $maxParams). '
                  'Builder pattern veya parametre nesnesi kullanmayı düşünün.',
              filePath: filePath,
              line: member.offset,
              suggestion: 'Builder pattern, parametre nesnesi veya named parameters kullanın.',
            ),
          );
        }
      }
    }

    // Derin inheritance kontrolü
    _checkInheritanceDepth(node, className);

    super.visitClassDeclaration(node);
  }

  void _checkInheritanceDepth(ClassDeclaration node, String className) {
    final element = node.classElement;
    if (element == null) return;

    var depth = 0;
    InterfaceType? current = element.supertype;
    final maxDepth = config.getThreshold('architecture', 'max_inheritance_depth', 3);

    while (current != null) {
      final typeName = current.element.name;
      if (typeName == 'Object') break;
      depth++;
      current = current.element.supertype;
    }

    if (depth > maxDepth) {
      issues.add(
        Issue(
          ruleId: 'arch-deep-inheritance',
          severity: Severity.warning,
          category: IssueCategory.architecture,
          message:
              '"$className" sınıfı derin bir kalıtım zincirine sahip: $depth seviye (eşik: $maxDepth). '
              'Composition over inheritance tercih edin.',
          filePath: filePath,
          // ignore: deprecated_member_use
          line: node.name.offset,
          suggestion:
              'Kalıtım yerine composition (mixin veya delegation) kullanmayı değerlendirin.',
        ),
      );
    }
  }
}
