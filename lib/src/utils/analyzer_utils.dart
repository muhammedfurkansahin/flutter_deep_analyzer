import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

extension NamedTypeExtension on NamedType {
  String get nameString {
    final dyn = this as dynamic;
    try {
      return dyn.name.lexeme as String;
    } catch (_) {
      try {
        return dyn.name2.lexeme as String;
      } catch (_) {}
    }
    return toSource().split('<').first;
  }
}

extension AstNodeNameExtension on AstNode {
  String get nodeName {
    final dyn = this as dynamic;
    // Try if name is an Identifier (analyzer < 7.x, 8.x, etc.)
    try {
      final nameNode = dyn.name;
      if (nameNode != null) {
        if (nameNode is SimpleIdentifier) {
          return nameNode.name;
        }
      }
    } catch (_) {}

    // Try if name is a Token (analyzer 10.x)
    try {
      final nameNode = dyn.name;
      if (nameNode != null) {
        return nameNode.lexeme as String;
      }
    } catch (_) {}

    // Fallback if there's no name property
    return '';
  }
}

extension ClassDeclarationExtension on ClassDeclaration {
  ClassElement? get classElement {
    final dyn = this as dynamic;
    try {
      final fragment = dyn.declaredFragment;
      if (fragment != null) {
        return fragment.element as ClassElement;
      }
    } catch (_) {}
    try {
      return dyn.declaredElement as ClassElement?;
    } catch (_) {}
    return null;
  }
}

extension DartTypeExtension on DartType {
  String get displayString {
    final dyn = this as dynamic;
    try {
      return dyn.getDisplayString(withNullability: false) as String;
    } catch (_) {
      try {
        return dyn.getDisplayString()
            as String; // older versions didn't require withNullability maybe? Or older versions required it.
      } catch (_) {}
    }
    return '';
  }
}
