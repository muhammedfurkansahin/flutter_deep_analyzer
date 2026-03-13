import 'dart:convert';

import '../models/analysis_result.dart';
import '../models/issue.dart';
import '../models/score.dart';
import 'base_reporter.dart';

/// SonarQube Generic Issue Data Formatında rapor üreten reporter.
/// CI/CD ortamlarında doğrudan analize dahil edebilmek için kullanılır.
class SonarQubeReporter extends BaseReporter {
  @override
  String report(AnalysisResult result, ProjectScore score) {
    final sonarqubeIssues = result.issues.map((issue) {
      return {
        'engineId': 'flutter_deep_analyzer',
        'ruleId': issue.ruleId,
        'severity': _mapSeverity(issue.severity),
        'type': _mapType(issue.category),
        'primaryLocation': {
          'message': issue.message,
          'filePath': issue.filePath,
          'textRange': {
            'startLine': issue.line,
            'startColumn': issue.column > 0 ? issue.column : 0,
          }
        }
      };
    }).toList();

    final json = {
      'issues': sonarqubeIssues,
    };

    return const JsonEncoder.withIndent('  ').convert(json);
  }

  String _mapSeverity(Severity severity) {
    switch (severity) {
      case Severity.error:
        return 'CRITICAL'; // veya BLOCKER
      case Severity.warning:
        return 'MAJOR';
      case Severity.style:
        return 'MINOR';
      case Severity.info:
        return 'INFO';
    }
  }

  String _mapType(IssueCategory category) {
    switch (category) {
      case IssueCategory.security:
        return 'VULNERABILITY';
      case IssueCategory.memoryLeak:
      case IssueCategory.raceCondition:
      case IssueCategory.architecture:
        return 'BUG';
      default:
        return 'CODE_SMELL';
    }
  }
}
