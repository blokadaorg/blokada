import 'dart:io';

import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:via/dep/dep.dart';

class DepGenerator extends GeneratorForAnnotation<Traced> {
  @override
  dynamic generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is ClassElement) {
      print("Dep: ${element.name}");

      var typeOfInjected = element.supertype ?? element.thisType;
      if (typeOfInjected.isDartCoreObject) typeOfInjected = element.thisType;

      // final log = annotation.read('log').boolValue;
      // final onlyVia = annotation.read('onlyVia').boolValue;

      final name = element.name;
      final genType = element.thisType.toString();

      List<String> fields = [];
      List<String> methods = [];

      for (final member in element.children) {
        if (member is MethodElement) {
          if (member.isStatic) {
            continue;
          }

          final methodName = member.name;
          final returnType = member.returnType.toString();
          final params =
              member.parameters.map((e) => "${e.type} ${e.name}").join(", ");
          final paramsInvocation =
              member.parameters.map((e) => e.name).join(", ");

          final template =
              methodName.startsWith("_") ? _method : _methodWithLogging;
          methods.add(template
              .replaceAll("#classname#", name)
              .replaceAll("#return#", returnType)
              .replaceAll("#name#", methodName)
              .replaceAll("#params#", params)
              .replaceAll("#params_invocation#", paramsInvocation));
        } else if (member is FieldElement) {
          final name = member.name;
          final fullType = member.type.toString();
          //final type = fullType.split("<").first;

          fields.add(_fieldGet
              .replaceAll("#type#", fullType)
              .replaceAll("#name#", name));

          if (!member.isFinal) {
            fields.add(_fieldSet
                .replaceAll("#type#", fullType)
                .replaceAll("#name#", name));
          }
        }
      }

      var out = _class
          .replaceAll("#name#", genType)
          .replaceAll("#fields#", fields.join("\n"))
          .replaceAll("#methods#", methods.join("\n"));

      return out;
    }

    return null; // Return null if the element is not annotated
  }
}

const _class = '''
class \$#name# implements #name# {
  late final #name# delegate = dep(instanceName: 'origin');

  #fields#

  #methods#
}
''';

const _methodWithLogging = '''
@override
#return# #name#(#params#) {
  print("enter #classname#:#name#");
  final result = delegate.#name#(#params_invocation#);
  print("exit #classname#:#name#");
  return result;
}
''';

const _method = '''
@override
#return# #name#(#params#) {
  return delegate.#name#(#params_invocation#);
}
''';

const _fieldGet = '''
@override
#type# get #name# => delegate.#name#;
''';

const _fieldSet = '''
@override
set #name#(#type# #name#) {
  delegate.#name# = #name#;
}
''';
