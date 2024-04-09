import 'dart:io';

import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:via/via.dart';
import 'package:via_generator/common.dart';

class ModuleGenerator extends GeneratorForAnnotation<Module> {
  final rForType = RegExp(r"forType = Type \((.*?)\)");
  final rUseType = RegExp(r"useType = Type \((.*?)\)");
  final rKey = RegExp(r"of = String \('(\w+)'\)");

  @override
  dynamic generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is ClassElement) {
      print("Module: ${element.name}");

      List<String> registrations = ["dynamic instance;"];
      List<String> provides = [];

      var matchers = annotation.read('matchers');
      if (matchers.isList) {
        for (var matcher in matchers.listValue) {
          final bruteForce = matcher.toString(); // I have no patience
          final key = rKey.firstMatch(bruteForce)!.group(1);
          final forTypeR = rForType.firstMatch(bruteForce)!.group(1)!;
          final useTypeR = rUseType.firstMatch(bruteForce)!.group(1)!;

          final forType = forTypeR.replaceFirst("*", "");
          final useType = useTypeR.replaceFirst("*", "");

          if (forType.contains("dynamic"))
            throw Exception(
                "Generic type not specified in matcher: $bruteForce");

          provides.add("$key:$forType");
          registrations.add("");
          registrations.add("instance = _\$$useType();");
          registrations
              .add("injector.register<${forType}>(instance, key: '$key');");
          if (forType != useType) {
            provides.add(useType);
            registrations
                .add("injector.register<${useType}>(instance, key: '$key');");
          }
        }
      } else {
        throw Exception("No matchers provided for module ${element.name}");
      }

      var out = _template
          .replaceAll("#name#", element.thisType.toString())
          .replaceAll("#registrations#", registrations.join("\n"));

      // Add the provides to common map used later by BootstrapGenerator
      final act = annotation.read('act');
      final s = act.peek('scenario')?.stringValue ?? "any";
      final p = act
              .peek('platform')
              ?.objectValue
              .getField('_name')
              ?.toStringValue() ??
          "any";
      final f = act.peek('flavor')?.stringValue ?? "any";
      print("module: $s, $p, $f");

      try {
        provides.sort();
        commonProvides[s] ??= {};
        commonProvides[s]![p] ??= {};
        commonProvides[s]![p]![f] ??= [];

        commonProvides[s]![p]![f]!.addAll(provides);
        print(commonProvides);
      } catch (e, s) {
        print(e);
        print(s);
        throw Exception("Error adding provides to common map");
      }

      return out;
    }

    return null; // Return null if the element is not annotated
  }
}

const _template = '''
class _\$#name# {
  _\$#name#() {
      #registrations#
  }
}
''';
