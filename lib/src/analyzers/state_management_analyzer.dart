import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import 'base_analyzer.dart';

/// State Management Analyzer
///
/// Kontrol edilen kurallar:
/// - Bloc: Public alan kontrolü
/// - Bloc: Asenkron işlem sonrası emit yapılması (mounted gibi ele alınabilir)
/// - Riverpod: ref.watch'in sadece build içerisinde kullanılması
/// - GetX: Controller'ların dispose edilip edilmediği
class StateManagementAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  StateManagementAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory
      .bestPractice; // Veya özel State Management kategorisi açılabilir. Şimdilik bestPractice kullanılabilir.

  @override
  String get name => 'State Management Analyzer';

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];

    // State management konfigürasyon üzerinden kapalıysa geç
    if (!config.isCategoryEnabled('state_management')) return issues;

    final visitor = _StateManagementVisitor(filePath: filePath, issues: issues, config: config);
    unit.unit.visitChildren(visitor);

    return issues;
  }
}

class _StateManagementVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;

  _StateManagementVisitor({required this.filePath, required this.issues, required this.config});

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // ignore: deprecated_member_use
    final superclassName = node.extendsClause?.superclass.toSource();

    // Bloc/Cubit public fields check
    if (superclassName == 'Bloc' || superclassName == 'Cubit') {
      // ignore: deprecated_member_use
      final fields = node.members.whereType<FieldDeclaration>().toList();
      for (final field in fields) {
        for (final variable in field.fields.variables) {
          // ignore: deprecated_member_use
          final fieldName = variable.name.lexeme;
          if (!fieldName.startsWith('_')) {
            issues.add(
              Issue(
                ruleId: 'sm-bloc-public-field',
                severity: Severity.warning,
                category: IssueCategory.bestPractice,
                message:
                    'Bloc/Cubit sınıflarında public field ($fieldName) kullanılamaz. State akışını bozabilir.',
                filePath: filePath,
                line: variable.offset,
                suggestion: 'Alanı private yapın ve state üreterek güncelleyin.',
              ),
            );
          }
        }
      }
    }

    // Riverpod ref.read ve ref.watch kuralları - Sınıf seviyesinde basit kontrol
    if (superclassName == 'ConsumerWidget' || superclassName == 'ConsumerState') {
      // Bu widgetlar için build metodunu bulalım.
      // ignore: deprecated_member_use
      final methods = node.members.whereType<MethodDeclaration>();
      for (final method in methods) {
        // ignore: deprecated_member_use
        final methodName = method.name.lexeme;

        // build methodu değilse ve içinde ref.watch geçiyorsa uyar!
        if (methodName != 'build') {
          method.body.accept(_RefWatchVisitor(issues, filePath));
        }
      }
    }

    // GetX - GetxController dispose (onClose) check
    if (superclassName == 'GetxController') {
      // ignore: deprecated_member_use
      final methods = node.members.whereType<MethodDeclaration>();
      for (final method in methods) {
        // ignore: deprecated_member_use
        if (method.name.lexeme == 'onClose') {
          // onClose içinde super.onClose() çağrılmış mı kontrol et.
          final source = method.body.toSource();
          if (!source.contains('super.onClose()')) {
            issues.add(
              Issue(
                ruleId: 'sm-getx-missing-super-onclose',
                severity: Severity.warning,
                category: IssueCategory.bestPractice,
                message:
                    'GetxController türetilmiş sinifinda onClose() metodunda super.onClose() cagrilmamis. Bellek sizintisi olabilir.',
                filePath: filePath,
                line: method.offset,
                suggestion:
                    'onClose() metodu icerisine super.onClose(); formunda base dispose cagirisi ekleyin.',
              ),
            );
          }
        }
      }
    }

    super.visitClassDeclaration(node);
  }
}

class _RefWatchVisitor extends RecursiveAstVisitor<void> {
  final List<Issue> issues;
  final String filePath;

  _RefWatchVisitor(this.issues, this.filePath);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'watch' && node.target?.toSource() == 'ref') {
      issues.add(
        Issue(
          ruleId: 'sm-riverpod-watch-outside-build',
          severity: Severity.error,
          category: IssueCategory.bestPractice,
          message:
              'Riverpod ref.watch metodu build() dısinda cagirildi. Performans veya calisma zamani sorunlarina yol acar.',
          filePath: filePath,
          line: node.offset,
          suggestion: 'Callbackler icerisinde veya build disinda ref.read kullanin.',
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}
