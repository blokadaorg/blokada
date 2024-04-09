import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:via/annotations.dart';
import 'package:via_generator/common.dart';

class ContextGenerator extends GeneratorForAnnotation<ContextAnnotation> {
  // @override
  // dynamic generateForAnnotatedElement(
  //     Element element, ConstantReader annotation, BuildStep buildStep) {
  //   if (element is! MethodElement) {
  //     throw InvalidGenerationSourceError(
  //         'The @Trace annotation can only be used on methods.',
  //         element: element);
  //   }

  //   final methodName = element.displayName;
  //   final returnType = element.returnType;

  //   print("running ner");

  //   // Here you would add the logic to generate the mixin and logging
  //   // For simplicity, this example just wraps the method call.
  //   return '''
  //   @override
  //   $returnType $methodName() {
  //     print('Entering $methodName');
  //     final result = super.$methodName();
  //     print('Exiting $methodName');
  //     return result;
  //   }
  //   ''';
  // }

  @override
  dynamic generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is MixinElement) {
      final name = element.name;

      List<String> constructorParams = [];
      List<String> constructorAssignments = [];
      List<String> emptyParams = [];
      List<String> emptyAssignments = [];
      List<String> copyConstructorParams = [];
      List<String> copyAssignments = [];
      List<String> testSetters = [];
      List<String> testGetters = [];

      for (final member in element.children) {
        if (member is FieldElement) {
          if (member.isLate) {
            if (!member.name.startsWith("_"))
              throw Exception("Late fields must be private");

            // Used by States generator
            contextRequiredFields[name] ??= [];
            contextRequiredFields[name]!.add(member);

            emptyParams.add("${member.type} ${noUnderscore(member.name)},");
            emptyAssignments
                .add("${member.name} = ${noUnderscore(member.name)};");
            copyAssignments.add("c.${member.name} = ${member.name};");
          } else {
            constructorParams
                .add("${member.type} ${noUnderscore(member.name)},");
            constructorAssignments
                .add("this.${member.name} = ${noUnderscore(member.name)};");
            copyConstructorParams.add("${member.name},");
          }

          if (member.name.startsWith("_")) {
            testSetters.add(
                "set inject${firstLetterUppercase(noUnderscore(member.name))}(${member.type} v) => ${member.name} = v;");
            testGetters.add(
                "${member.type} get inject${firstLetterUppercase(noUnderscore(member.name))} => ${member.name};");
          }
        }
      }

      var out = _template
          .replaceAll("#name#", name)
          .replaceAll("#constructor_params#", constructorParams.join("\n"))
          .replaceAll(
              "#constructor_assignments#", constructorAssignments.join("\n"))
          .replaceAll("#empty_params#", emptyParams.join("\n"))
          .replaceAll("#empty_assignments#", emptyAssignments.join("\n"))
          .replaceAll(
              "#copy_constructor_params#", copyConstructorParams.join("\n"))
          .replaceAll("#copy_assignments#", copyAssignments.join("\n"));

      // Also make a test class for mocking
      out += _templateTesting
          .replaceAll("#name#", name)
          .replaceAll("#setters#", testSetters.join("\n"))
          .replaceAll("#getters#", testGetters.join("\n"));

      return out;
    }

    return null; // Return null if the element is not annotated
  }
}

const _template = '''
class _\$#name# with Context<#name#>, #name# {
  _\$#name#(
    #constructor_params#
  ) {
    #constructor_assignments#
  }

  _\$#name#.empty(
    #empty_params#
  ) {
    #empty_assignments#
  }

  @override
  Context<#name#> copy() {
    final c = _\$#name#(
      #copy_constructor_params#
    );
    #copy_assignments#
    return c;
  }
}
''';

const _templateTesting = '''
class Test#name# with Context<#name#>, #name# {
  #setters#

  #getters#

  @override
  Context<#name#> copy() {
    throw Exception("Test context cannot be copied");
  }
}
''';
