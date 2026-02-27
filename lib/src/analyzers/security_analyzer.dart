import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config/analyzer_config.dart';
import '../models/issue.dart';
import '../utils/analyzer_utils.dart';
import 'base_analyzer.dart';

/// Güvenlik Analyzer
///
/// Kontrol edilen kurallar:
/// - Hardcoded secret/API key/password
/// - HTTP (non-HTTPS) URL kullanımı
/// - dart:mirrors kullanımı
/// - Güvensiz Random kullanımı
/// - SQL injection riski
/// - WebView JS injection
/// - SharedPreferences'da hassas veri
class SecurityAnalyzer extends BaseAnalyzer {
  final AnalyzerConfig config;

  SecurityAnalyzer({required this.config});

  @override
  IssueCategory get category => IssueCategory.security;

  @override
  String get name => 'Güvenlik Analyzer';

  // Hardcoded secret tespiti için paternler
  static final _secretPatterns = [
    RegExp(
      r'''(?:api[_-]?key|apikey)\s*[:=]\s*['\"][a-zA-Z0-9_\-]{10,}['\"]''',
      caseSensitive: false,
    ),
    RegExp(
      r'''(?:secret|token|password|passwd|pwd|api_secret)\s*[:=]\s*['\"][^\s'"]{8,}['\"]''',
      caseSensitive: false,
    ),
    RegExp(r'''(?:bearer|authorization)\s*[:=]\s*['\"][^\s'"]{10,}['\"]''', caseSensitive: false),
    RegExp(
      r'''(?:aws_access_key|aws_secret)\s*[:=]\s*['\"][a-zA-Z0-9/+=]{10,}['\"]''',
      caseSensitive: false,
    ),
    RegExp(
      r'''(?:firebase|google|github|slack|stripe)\s*[_-]?\s*(?:key|token|secret)\s*[:=]\s*['\"][^\s'"]{10,}['\"]''',
      caseSensitive: false,
    ),
    RegExp(r'''AKIA[0-9A-Z]{16}'''), // AWS access key pattern
    RegExp(r'''sk-[a-zA-Z0-9]{20,}'''), // OpenAI API key pattern
  ];

  @override
  Future<List<Issue>> analyze(ResolvedUnitResult unit, String filePath, String fileContent) async {
    final issues = <Issue>[];

    // Satır bazlı kontroller
    _checkHardcodedSecrets(fileContent, filePath, issues);
    _checkInsecureHttp(fileContent, filePath, issues);

    // AST bazlı kontroller
    final visitor = _SecurityVisitor(
      filePath: filePath,
      issues: issues,
      config: config,
      fileContent: fileContent,
    );
    unit.unit.visitChildren(visitor);

    // Import bazlı kontroller
    _checkDangerousImports(unit.unit, filePath, issues);

    return issues;
  }

  void _checkHardcodedSecrets(String fileContent, String filePath, List<Issue> issues) {
    // .env ve config dosyalarını yoksay
    if (filePath.endsWith('.env') || filePath.contains('config/constants')) {
      return;
    }

    final lines = fileContent.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Yorum satırlarını yoksay
      if (line.trim().startsWith('//') || line.trim().startsWith('*')) continue;

      for (final pattern in _secretPatterns) {
        if (pattern.hasMatch(line)) {
          issues.add(
            Issue(
              ruleId: 'sec-hardcoded-secret',
              severity: Severity.error,
              category: IssueCategory.security,
              message: 'Potansiyel hardcoded secret/API key tespit edildi. '
                  'Secrets\'ları environment variable veya güvenli depolama ile yönetin.',
              filePath: filePath,
              line: i + 1,
              codeSnippet: _maskSecret(line.trim()),
              suggestion: 'flutter_dotenv paketi veya Platform.environment kullanarak '
                  'secrets\'ları env variable olarak yönetin. '
                  'Mobilde flutter_secure_storage kullanın.',
            ),
          );
          break; // Aynı satırda birden fazla uyarı verme
        }
      }
    }
  }

  void _checkInsecureHttp(String fileContent, String filePath, List<Issue> issues) {
    final lines = fileContent.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('//') || line.trim().startsWith('*')) continue;

      // http:// URL'leri bul (localhost hariç)
      final httpMatch = RegExp(r'''http://(?!localhost|127\.0\.0\.1|10\.|192\.168\.)''');
      if (httpMatch.hasMatch(line)) {
        issues.add(
          Issue(
            ruleId: 'sec-insecure-http',
            severity: Severity.error,
            category: IssueCategory.security,
            message: 'Güvensiz HTTP bağlantısı tespit edildi. HTTPS kullanın.',
            filePath: filePath,
            line: i + 1,
            codeSnippet: line.trim(),
            suggestion: 'http:// yerine https:// kullanın. Network iletişimi şifrelenmeli.',
          ),
        );
      }
    }
  }

  void _checkDangerousImports(CompilationUnit unit, String filePath, List<Issue> issues) {
    for (final directive in unit.directives) {
      if (directive is ImportDirective) {
        final uri = directive.uri.stringValue;
        if (uri == null) continue;

        if (uri == 'dart:mirrors') {
          issues.add(
            Issue(
              ruleId: 'sec-eval-usage',
              severity: Severity.error,
              category: IssueCategory.security,
              message:
                  'dart:mirrors kullanımı güvenlik riski oluşturur ve Flutter\'da desteklenmez.',
              filePath: filePath,
              line: 1,
              suggestion: 'dart:mirrors yerine code generation (build_runner) veya '
                  'manuel reflection alternatifleri kullanın.',
            ),
          );
        }
      }
    }
  }

  String _maskSecret(String line) {
    // Secret değerleri maskele
    return line.replaceAllMapped(RegExp(r'''(['"])[a-zA-Z0-9_\-/+=]{8,}\1'''), (match) {
      final value = match.group(0)!;
      if (value.length > 6) {
        return '${value.substring(0, 3)}${'*' * (value.length - 6)}${value.substring(value.length - 3)}';
      }
      return '***';
    });
  }
}

class _SecurityVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<Issue> issues;
  final AnalyzerConfig config;
  final String fileContent;

  _SecurityVisitor({
    required this.filePath,
    required this.issues,
    required this.config,
    required this.fileContent,
  });

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.nameString;

    // Güvensiz Random kullanımı
    if (typeName == 'Random') {
      final constructorName = node.constructorName.name?.name;
      if (constructorName != 'secure') {
        issues.add(
          Issue(
            ruleId: 'sec-insecure-random',
            severity: Severity.warning,
            category: IssueCategory.security,
            message:
                'Güvensiz Random() kullanımı. Kriptografik işlemler için Random.secure() kullanın.',
            filePath: filePath,
            line: _getLineNumber(node.offset),
            suggestion:
                'Random() yerine Random.secure() kullanın, özellikle token/nonce üretiminde.',
          ),
        );
      }
    }

    // SharedPreferences'da hassas veri kontrolü
    if (typeName == 'SharedPreferences') {
      // Üst bağlamda 'password', 'token', 'secret' gibi key'ler aranır
      final parent = node.parent;
      if (parent != null) {
        final parentSource = parent.toSource().toLowerCase();
        if (parentSource.contains('password') ||
            parentSource.contains('token') ||
            parentSource.contains('secret') ||
            parentSource.contains('pin') ||
            parentSource.contains('credit_card')) {
          issues.add(
            Issue(
              ruleId: 'sec-insecure-storage',
              severity: Severity.warning,
              category: IssueCategory.security,
              message: 'SharedPreferences\'da hassas veri saklanıyor olabilir. '
                  'flutter_secure_storage kullanın.',
              filePath: filePath,
              line: _getLineNumber(node.offset),
              suggestion: 'Hassas veriler için flutter_secure_storage veya platform '
                  'keychain/keystore kullanın.',
            ),
          );
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // SharedPreferences write metodları kontrolü
    if (methodName == 'setString' || methodName == 'setInt') {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final firstArg = args.first.toSource().toLowerCase();
        if (firstArg.contains('password') ||
            firstArg.contains('token') ||
            firstArg.contains('secret') ||
            firstArg.contains('api_key') ||
            firstArg.contains('credit')) {
          issues.add(
            Issue(
              ruleId: 'sec-insecure-storage',
              severity: Severity.warning,
              category: IssueCategory.security,
              message: 'Hassas veri güvensiz depolamada saklanıyor. Key: ${args.first.toSource()}',
              filePath: filePath,
              line: _getLineNumber(node.offset),
              suggestion:
                  'flutter_secure_storage paketi kullanarak hassas verileri güvenli saklayın.',
            ),
          );
        }
      }
    }

    // SQL injection kontrolü
    if (methodName == 'rawQuery' || methodName == 'rawInsert' || methodName == 'rawDelete') {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final query = args.first;
        if (query is StringInterpolation || query is AdjacentStrings) {
          issues.add(
            Issue(
              ruleId: 'sec-sql-injection',
              severity: Severity.error,
              category: IssueCategory.security,
              message: 'SQL injection riski: String interpolation ile SQL sorgusu oluşturulmuş.',
              filePath: filePath,
              line: _getLineNumber(node.offset),
              suggestion:
                  'Parametreli sorgular kullanın. Ör: rawQuery("SELECT * FROM users WHERE id = ?", [userId])',
            ),
          );
        }
      }
    }

    // WebView evaluateJavascript kontrolü
    if (methodName == 'evaluateJavascript' ||
        methodName == 'runJavascript' ||
        methodName == 'runJavaScriptReturningResult') {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final jsCode = args.first;
        if (jsCode is StringInterpolation) {
          issues.add(
            Issue(
              ruleId: 'sec-xss-vulnerable',
              severity: Severity.warning,
              category: IssueCategory.security,
              message:
                  'WebView XSS riski: Kullanıcı girişi JavaScript koduna interpolate ediliyor.',
              filePath: filePath,
              line: _getLineNumber(node.offset),
              suggestion: 'Kullanıcı girişini sanitize edin veya postMessage API kullanın.',
            ),
          );
        }
      }
    }

    super.visitMethodInvocation(node);
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
