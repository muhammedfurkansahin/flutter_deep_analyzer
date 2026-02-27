import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import '../utils/analyzer_utils.dart';
import 'base_analyzer.dart';

/// Bellek Sızıntısı Analyzer
///
/// Kontrol edilen kurallar:
/// - Controller dispose eksikliği (TextEditingController, AnimationController, vb.)
/// - StreamController close eksikliği
/// - Timer cancel eksikliği
/// - StreamSubscription cancel eksikliği
/// - Listener remove eksikliği
/// - FocusNode/ScrollController dispose eksikliği
class MemoryLeakAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  MemoryLeakAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory.memoryLeak;

  @override
  String get name => 'Bellek Sızıntısı Analyzer';

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];
    final visitor = _MemoryLeakVisitor(
      filePath: filePath,
      issues: issues,
      config: config,
      fileContent: fileContent,
    );
    unit.unit.visitChildren(visitor);
    return issues;
  }
}

class _MemoryLeakVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;
  final String fileContent;

  // State sınıfında tanımlanan disposable kaynaklar
  final Set<String> _declaredControllers = {};
  final Set<String> _declaredStreamControllers = {};
  final Set<String> _declaredTimers = {};
  final Set<String> _declaredSubscriptions = {};
  final Set<String> _declaredFocusNodes = {};
  final Set<String> _declaredScrollControllers = {};
  final Set<String> _declaredAnimationControllers = {};

  // dispose/close/cancel edilen kaynaklar
  final Set<String> _disposedResources = {};

  bool _isInStateClass = false;
  bool _hasDisposeMethod = false;
  String? _currentClassName;
  int _classOffset = 0;

  // Disposable tip isimleri
  static const _controllerTypes = {
    'TextEditingController',
    'PageController',
    'TabController',
    'ScrollController',
  };

  static const _animationControllerTypes = {'AnimationController'};

  static const _focusNodeTypes = {'FocusNode', 'FocusScopeNode'};

  _MemoryLeakVisitor({
    required this.filePath,
    required this.issues,
    required this.config,
    required this.fileContent,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // ignore: deprecated_member_use
    _currentClassName = node.name.lexeme;
    // ignore: deprecated_member_use
    _classOffset = node.name.offset;

    // State sınıfı mı kontrol et
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superClass = extendsClause.superclass.nameString;
      _isInStateClass = superClass.startsWith('State');
    }

    if (_isInStateClass) {
      // Tüm alanları ve dispose metodunu tara
      _scanClassMembers(node);

      // Dispose edilen kaynakları topla
      _scanDisposeMethod(node);

      // Eksik dispose'ları raporla
      _reportMissingDisposes(node);
    }

    super.visitClassDeclaration(node);

    // Temizle
    _isInStateClass = false;
    _hasDisposeMethod = false;
    _currentClassName = null;
    _declaredControllers.clear();
    _declaredStreamControllers.clear();
    _declaredTimers.clear();
    _declaredSubscriptions.clear();
    _declaredFocusNodes.clear();
    _declaredScrollControllers.clear();
    _declaredAnimationControllers.clear();
    _disposedResources.clear();
  }

  void _scanClassMembers(ClassDeclaration node) {
    // ignore: deprecated_member_use
    for (final member in node.members) {
      // Dispose metodu var mı?
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        _hasDisposeMethod = true;
      }

      // Field tanımlamalarını tara
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          final name = variable.name.lexeme;
          final typeAnnotation = member.fields.type;
          String? typeName;

          if (typeAnnotation is NamedType) {
            typeName = typeAnnotation.nameString;
          }

          // Initializer'dan tip çıkar
          if (typeName == null && variable.initializer != null) {
            final init = variable.initializer;
            if (init is InstanceCreationExpression) {
              typeName = init.constructorName.type.nameString;
            }
          }

          if (typeName == null) continue;

          if (_controllerTypes.contains(typeName)) {
            _declaredControllers.add(name);
          } else if (typeName == 'ScrollController') {
            _declaredScrollControllers.add(name);
          } else if (_animationControllerTypes.contains(typeName)) {
            _declaredAnimationControllers.add(name);
          } else if (typeName == 'StreamController' || typeName.startsWith('StreamController')) {
            _declaredStreamControllers.add(name);
          } else if (typeName == 'Timer' || typeName == 'Timer?') {
            _declaredTimers.add(name);
          } else if (typeName == 'StreamSubscription' ||
              typeName.startsWith('StreamSubscription')) {
            _declaredSubscriptions.add(name);
          } else if (_focusNodeTypes.contains(typeName)) {
            _declaredFocusNodes.add(name);
          }
        }
      }
    }
  }

  void _scanDisposeMethod(ClassDeclaration node) {
    // ignore: deprecated_member_use
    for (final member in node.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        final body = member.body.toSource();

        // dispose(), close(), cancel() çağrılarını bul
        final disposePattern = RegExp(r'(\w+)\.(dispose|close|cancel)\(\)');
        for (final match in disposePattern.allMatches(body)) {
          _disposedResources.add(match.group(1)!);
        }

        // Null-safe versiyonlar: _controller?.dispose()
        final nullSafePattern = RegExp(r'(\w+)\?\.(dispose|close|cancel)\(\)');
        for (final match in nullSafePattern.allMatches(body)) {
          _disposedResources.add(match.group(1)!);
        }
      }
    }
  }

  void _reportMissingDisposes(ClassDeclaration node) {
    final allResources = <String, _ResourceInfo>{};

    for (final name in _declaredControllers) {
      allResources[name] = _ResourceInfo('Controller', 'dispose', Severity.error);
    }
    for (final name in _declaredAnimationControllers) {
      allResources[name] = _ResourceInfo('AnimationController', 'dispose', Severity.error);
    }
    for (final name in _declaredStreamControllers) {
      allResources[name] = _ResourceInfo('StreamController', 'close', Severity.error);
    }
    for (final name in _declaredTimers) {
      allResources[name] = _ResourceInfo('Timer', 'cancel', Severity.warning);
    }
    for (final name in _declaredSubscriptions) {
      allResources[name] = _ResourceInfo('StreamSubscription', 'cancel', Severity.warning);
    }
    for (final name in _declaredFocusNodes) {
      allResources[name] = _ResourceInfo('FocusNode', 'dispose', Severity.warning);
    }
    for (final name in _declaredScrollControllers) {
      allResources[name] = _ResourceInfo('ScrollController', 'dispose', Severity.warning);
    }

    if (allResources.isEmpty) return;

    if (!_hasDisposeMethod && allResources.isNotEmpty) {
      issues.add(
        Issue(
          ruleId: 'mem-missing-dispose',
          severity: Severity.error,
          category: IssueCategory.memoryLeak,
          message: '"$_currentClassName" sınıfında dispose() metodu yok ama '
              '${allResources.length} disposable kaynak var: '
              '${allResources.keys.join(", ")}.',
          filePath: filePath,
          line: _getLineNumber(_classOffset),
          suggestion:
              'dispose() metodunu override edip tüm controller, subscription ve timer\'ları temizleyin. '
              'super.dispose() çağrısını unutmayın.',
        ),
      );
      return;
    }

    // Dispose edilmemiş kaynakları raporla
    for (final entry in allResources.entries) {
      if (!_disposedResources.contains(entry.key)) {
        final info = entry.value;
        final action = info.action;
        issues.add(
          Issue(
            ruleId: _getRuleId(info.typeName),
            severity: info.severity,
            category: IssueCategory.memoryLeak,
            message: '"$_currentClassName" sınıfında "${entry.key}" (${info.typeName}) '
                'dispose metodunda $action() edilmemiş. Bellek sızıntısına neden olabilir.',
            filePath: filePath,
            line: _getLineNumber(_classOffset),
            suggestion: 'dispose() metoduna "${entry.key}.$action();" satırını ekleyin.',
          ),
        );
      }
    }
  }

  String _getRuleId(String typeName) {
    switch (typeName) {
      case 'StreamController':
        return 'mem-stream-not-closed';
      case 'Timer':
        return 'mem-timer-not-cancelled';
      case 'AnimationController':
        return 'mem-animation-controller';
      case 'StreamSubscription':
        return 'mem-listener-not-removed';
      case 'FocusNode':
      case 'FocusScopeNode':
        return 'mem-focus-node-dispose';
      case 'ScrollController':
        return 'mem-scroll-controller';
      default:
        return 'mem-missing-dispose';
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

class _ResourceInfo {
  final String typeName;
  final String action;
  final Severity severity;

  const _ResourceInfo(this.typeName, this.action, this.severity);
}
