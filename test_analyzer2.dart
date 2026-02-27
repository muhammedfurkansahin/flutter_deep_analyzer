import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

void main() {
  var result = parseString(content: "class A extends B<String> {}");
  var clazz = result.unit.declarations[0] as ClassDeclaration;
  var superClass = clazz.extendsClause!.superclass;
  
  print("toSource: ${superClass.toSource()}");
}
