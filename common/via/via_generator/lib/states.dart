import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:via/annotations.dart';
import 'package:via_generator/common.dart';

class StatesGenerator extends GeneratorForAnnotation<States> {
  @override
  dynamic generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is MixinElement) {
      final fullName = element.name;
      final actorName = fullName.replaceFirst("States", "Actor");
      final contextType = annotation.read('context').typeValue;
      final contextName =
          contextType.toString().replaceAll("*", ""); // fix null safety

      var knownContext = contextRequiredFields[contextName];
      if (knownContext == null) throw Exception("Unknown context $contextName");

      var initialState = "";
      var fatalState = "";

      List<String> constructorParams = [];
      List<String> contextParams = [];

      List<String> statesMap = [];
      List<String> actionsMap = [];

      List<String> actions = [];

      for (final member in knownContext) {
        constructorParams
            .add("required ${member.type} ${noUnderscore(member.name)},");
        contextParams.add("${noUnderscore(member.name)},");
      }

      for (final member in element.children) {
        if (member is MethodElement) {
          if (!member.isStatic) {
            print("Warning: skipping non-static method: ${member.name}");
            continue;
          }

          final stateName = member.name;
          if (member.parameters.first.type.toString() != contextName)
            throw Exception("States must take $contextName as first param");

          if (isAnnotated(member, InitialStateAnnotation)) {
            if (initialState.isNotEmpty)
              throw Exception("Multiple initial states");
            initialState = stateName;
          }

          if (isAnnotated(member, FatalStateAnnotation)) {
            if (fatalState.isNotEmpty) throw Exception("Multiple fatal states");
            fatalState = stateName;
          }

          if (member.parameters.length == 1) {
            // Normal states with no parameters
            statesMap.add('$fullName.$stateName: "$stateName",');
          } else {
            // Actions can contain parameters
            if (!stateName.startsWith("on"))
              throw Exception("Actions must start with 'on'");

            actionsMap.add('_$stateName: "$stateName",');
            actions.add(_makeAction(contextName, fullName, member));
          }
        }
      }

      if (initialState.isEmpty) throw Exception("No initial state");
      if (fatalState.isEmpty) throw Exception("No fatal state");

      return _template
          .replaceAll("#name#", actorName)
          .replaceAll("#name_states#", fullName)
          .replaceAll("#name_context#", contextName)
          .replaceAll("#initial_state#", initialState)
          .replaceAll("#fatal_state#", fatalState)
          .replaceAll("#constructor_params#", constructorParams.join("\n"))
          .replaceAll("#context_params#", contextParams.join("\n"))
          .replaceAll("#states_map#", statesMap.join("\n"))
          .replaceAll("#actions_map#", actionsMap.join("\n"))
          .replaceAll("#actions#", actions.join("\n"));
    }

    return null; // Return null if the element is not annotated
  }
}

String _makeAction(
    String contextName, String statesName, MethodElement member) {
  final actionName = member.name.replaceFirst("on", "");

  final fields = member.parameters.skip(1).map((e) {
    return "late ${e.type} ${_internalParamName(e.name, actionName)};";
  }).join("\n");

  final assignments = member.parameters.skip(1).map((e) {
    return "${_internalParamName(e.name, actionName)} = ${e.name};";
  }).join("\n");

  final actionParamsSignature = member.parameters.skip(1).map((e) {
    return "${e.type} ${e.name}";
  }).join(", ");

  final actionParamsCall = ([member.parameters.first.name] +
          member.parameters.skip(1).map((e) {
            return _internalParamName(e.name, actionName);
          }).toList())
      .join(", ");

  return _templateAction
      .replaceAll("#fields#", fields)
      .replaceAll("#action#", firstLetterLowercase(actionName))
      .replaceAll("#params#", actionParamsSignature)
      .replaceAll("#params_assignments#", assignments)
      .replaceAll("#state_name#", member.name)
      .replaceAll("#name_context#", contextName)
      .replaceAll("#states#", statesName)
      .replaceAll("#params_with_context#", actionParamsCall);
}

String _internalParamName(String name, String action) => "_${name}${action}";

const _template = '''
class #name# {
  late final StateMachine<#name_context#> _machine;

  #name#({
    #constructor_params#
  }) {
    _machine = StateMachine(
      "#initial_state#",
      _\$#name_context#.empty(
        #context_params#
      ),
      FailBehavior("#fatal_state#"),
    );

    _machine.states = {
      #states_map#
      #actions_map#
    };

    _machine.enter(#name_states#.#initial_state#);
  }

  
  #actions#

  Future<#name_context#> waitForState(StateFn<#name_context#> state) =>
      _machine.waitForState(state);

  whenState(StateFn<#name_context#> state, Function(#name_context#) fn) =>
      _machine.whenState(state, fn);

  addOnState(StateFn<#name_context#> state, String name, Function(String, #name_context#) fn) =>
      _machine.addOnState(state, name, fn);

  enter(StateFn<#name_context#> state) => _machine.enter(state);
}
''';

const _templateAction = '''
  // Action: #state_name#
  #fields#

  #action#(#params#) {
    #params_assignments#
    _machine.enter(_#state_name#);
  }
  _#state_name#(#name_context# c) => #states#.#state_name#(#params_with_context#);
''';
