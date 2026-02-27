import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

void main() {
  var result = parseString(content: "class A extends B {}");
  var clazz = result.unit.declarations[0] as ClassDeclaration;
  var superClass = clazz.extendsClause!.superclass;
  
  try {
    print((superClass as dynamic).name2.lexeme);
  } catch(e) {
    print("name2 failed: $e");
  }

  try {
    print((superClass as dynamic).name.lexeme);
  } catch(e) {
    print("name failed: $e");
  }
}
