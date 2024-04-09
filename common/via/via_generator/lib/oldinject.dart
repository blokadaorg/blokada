import 'dart:io';

import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:via/via.dart';

import 'common.dart';

class InjectGenerator extends GeneratorForAnnotation<Injected> {
  final viaTypes = ["ViaBase", "ViaList", "ViaCall"];

  @override
  dynamic generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is ClassElement) {
      print("Inject: ${element.name}");

      var typeOfInjected = element.supertype ?? element.thisType;
      if (typeOfInjected.isDartCoreObject) typeOfInjected = element.thisType;

      final log = annotation.read('log').boolValue;
      final onlyVia = annotation.read('onlyVia').boolValue;

      final name = element.name;
      final genType = element.thisType.toString();

      List<String> attach = [];
      List<String> methods = [];

      List<String> needs = [];

      for (final member in element.children) {
        if (member is FieldElement) {
          final spec = getMatcherSpecAnnotation(member);
          final keyFromSpec = spec?.of ?? Via.ofDefault;
          final ctx = spec?.ctx ?? noUnderscore(member.name);
          final fullType = member.type.toString();
          final t = fullType.split("<").first;

          if (viaTypes.contains(t)) {
            if (!member.isFinal)
              throw Exception(
                  "Injected field must be final: ${member.name}, $name");

            if (!member.name.startsWith("_"))
              throw Exception(
                  "Injected field must be private: ${member.name}, $name");

            // Handling via types
            attach.add(
                "${member.name}.inject(injector, MatcherSpec(of: '$keyFromSpec', ctx: '$ctx'));");

            var genericTypeClause = fullType.substring(
                fullType.indexOf("<") + 1, fullType.length - 1);
            if (t == "ViaCall") genericTypeClause = "void";
            needs.add("${keyFromSpec}:HandleVia<$genericTypeClause>");
            if (t == "ViaList") {
              needs.add("${keyFromSpec}:HandleVia<List<$genericTypeClause>>");
            }
          } else if (!onlyVia) {
            if (!member.isLate) continue;
            if (!member.isFinal)
              throw Exception(
                  "Injected field must be final: ${member.name}, $name");

            if (!member.name.startsWith("_"))
              throw Exception(
                  "Injected field must be private: ${member.name}, $name");

            // Handling any other types
            attach.add("${member.name} = injector.get(key: '$keyFromSpec');");
            needs.add("${keyFromSpec}:${member.type}");
          }
        } else if (member is MethodElement && log) {
          if (member.isStatic) {
            print("Warning: skipping static method: ${member.name}");
            continue;
          } else if (member.name.startsWith("_")) {
            continue;
          }

          final methodName = member.name;
          final returnType = member.returnType.toString();
          final params =
              member.parameters.map((e) => "${e.type} ${e.name}").join(", ");
          final paramsInvocation =
              member.parameters.map((e) => e.name).join(", ");

          methods.add(_methodTemplate
              .replaceAll("#classname#", name)
              .replaceAll("#return#", returnType)
              .replaceAll("#name#", methodName)
              .replaceAll("#params#", params)
              .replaceAll("#params_invocation#", paramsInvocation));
        }
      }

      final immediate = annotation.read('immediate').boolValue;
      final template = immediate ? _templateImmediate : _template;
      var out = template
          .replaceAll("#name#", genType)
          .replaceAll("#attach#", attach.join("\n"))
          .replaceAll("#methods#", methods.join("\n"));

      needs.sort();
      commonNeeds.addAll(needs);
      // File(
      //   "i.needs.g",
      // ).writeAsStringSync(needs.map((e) => "$e\n").join(),
      //     mode: FileMode.append, flush: true);

      return out;
    }

    return null; // Return null if the element is not annotated
  }
}

const _template = '''
class _\$#name# extends #name# with Injectable {
  @override
  inject() {
    #attach#
  }

  #methods#
}
''';

const _templateImmediate = '''
class _\$#name# extends #name# with Injectable {
  _\$#name#() {
    inject();
  }

  @override
  inject() {
    try {
      #attach#
    } catch (e) {
      print("Error injecting #name#: \$e");
    }
  }

  #methods#
}
''';

const _methodTemplate = '''
@override
#return# #name#(#params#) {
  print("#classname#:#name#");
  return super.#name#(#params_invocation#);
}
''';
