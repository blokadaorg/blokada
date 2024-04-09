import 'package:analyzer/dart/element/element.dart';
import 'package:via/via.dart';

Map<String, List<FieldElement>> contextRequiredFields = {};

String noUnderscore(String name) {
  if (name.startsWith("_")) return name.substring(1);
  return name;
}

String firstLetterLowercase(String name) {
  if (name.isEmpty) return name;
  return name[0].toLowerCase() + name.substring(1);
}

String firstLetterUppercase(String name) {
  if (name.isEmpty) return name;
  return name[0].toUpperCase() + name.substring(1);
}

bool isAnnotated(MethodElement methodElement, Type type) {
  return methodElement.metadata.any((elementAnnotation) {
    // Convert the annotation to a DartObject
    var dartObject = elementAnnotation.computeConstantValue();
    return dartObject?.type?.element?.name == type.toString();
  });
}

MatcherSpec? getMatcherSpecAnnotation(FieldElement element) {
  try {
    final a = element.metadata.firstWhere((elementAnnotation) {
      // Convert the annotation to a DartObject
      var dartObject = elementAnnotation.computeConstantValue();
      return dartObject?.type?.element?.name == "MatcherSpec";
    });
    final of = a.computeConstantValue()?.getField("of")?.toStringValue();
    final ctx = a.computeConstantValue()?.getField("ctx")?.toStringValue();
    if (of == null) return null;
    return MatcherSpec(of: of, ctx: ctx);
  } catch (_) {
    return null;
  }
}

List<String> commonNeeds = [];
Map<String, Map<String, Map<String, List<String>>>> commonProvides = {};
