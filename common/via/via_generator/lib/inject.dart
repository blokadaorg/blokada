import 'dart:io';

import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:via/dep/dep.dart';

class ResolveDepGenerator extends GeneratorForAnnotation<Inject> {
  @override
  dynamic generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is ClassElement) {
      final name = element.name;
      final genType = element.thisType.toString();

      print("ResolveDep: ${element.name}");

      //List<String> registrations = ["dynamic instance;"];
      List<String> registrations = [];

      for (final member in element.children) {
        if (member is FieldElement) {
          final fullType = member.type.toString();
          final type = fullType.split("<").first;

          if (!member.isLate) continue;
          if (!member.isFinal)
            throw Exception(
                "Injected field must be final: ${member.name}, $name");

          if (!member.name.startsWith("_"))
            throw Exception(
                "Injected field must be private: ${member.name}, $name");

          // Handling any other types
          registrations.add("${member.name} = \$$type();");
          //needs.add("${keyFromSpec}:${member.type}");
        }
      }

      var out = _template
          .replaceAll("#name#", element.thisType.toString())
          .replaceAll("#registrations#", registrations.join("\n"));

      return out;
    }

    return null; // Return null if the element is not annotated
  }
}

const _template = '''
class \$#name# extends #name# {
  \$#name#() {
      #registrations#
  }
}
''';
