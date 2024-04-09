import 'dart:io';

import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:via/via.dart';

import 'common.dart';

class BootstrapGenerator extends GeneratorForAnnotation<Bootstrap> {
  @override
  dynamic generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    print("Bootstrap: ${element.name}");

    final needs = commonNeeds.toSet();
    if (needs.isEmpty) throw Exception("No needs found");

    final act = annotation.read('act');
    final s = act.read('scenario').stringValue;
    final p =
        act.read('platform').objectValue.getField('_name')!.toStringValue();
    final f = act.read('flavor').stringValue;
    print("bootstrap: $s, $p, $f");

    Set<String> all = {};
    for (var ss in [s, "any"]) {
      for (var pp in [p, "any"]) {
        for (var ff in [f, "any"]) {
          final provides = commonProvides[ss]?[pp]?[ff];
          if (provides == null) continue;
          if (all.intersection(provides.toSet()).isNotEmpty) {
            throw Exception(
                "Inject: provides conflict for ($s, $p, $f). Found in $ss, $pp, $ff");
          }
          all.addAll(provides.toSet());
        }
      }
    }

    print("needs");
    print(needs);
    print("all");
    print(all);
    var diff = needs.difference(all);
    if (diff.isNotEmpty) {
      print("Inject: needs unmet for ($s, $p, $f): $diff");
      //throw Exception("Inject: needs unmet for ($s, $p, $f): $diff");
    }

    return null;
  }
}
