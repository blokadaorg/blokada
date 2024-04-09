import 'package:via/via.dart';

part 'example.g.dart';

// @context
// mixin ExampleContext {
//   String? name;
//   int value = 3;
//   Map<String, List<String>> map = {};

//   late Function(String) _action;
// }

// @States(ExampleContext)
// mixin ExampleStates {
//   @initialState
//   static initial(ExampleContext c) async {}

//   @fatalState
//   static fatal(ExampleContext c) async {}

//   static onHelloWorld(ExampleContext c, String name) async {}
// }

@Module([
  SimpleMatcher(Http),
  SimpleMatcher(Param<List<String>>),
  SimpleMatcher(Param<String>),
], act: ViaActSpec(scenario: "debug"))
class MainModule extends _$MainModule {}

// @Module(
//   [
//     SimpleMatcher(Http),
//     SimpleMatcher(Param<List<String>>),
//     SimpleMatcher(Param<String>),
//   ],
// )
// class InnyModule extends _$InnyModule {}

@Injected()
class Http {
  late final Param<List<String>> _param;
  //late final String _realThing;

  String doHttp() {
    //return _realThing;
    throw Exception("Should be never called");
  }
}

@Injected()
class Param<T> {
  final Type _type = T;

  T empty() {
    if (_type == List<String>) {
      return ["helloList"] as T;
    } else {
      return "hello" as T;
    }
  }
}

@Injected(log: true)
class MockedHttp extends Http {
  late final Param<List<String>> _param;

  @override
  String doHttp() {
    return "mocked=${_param.empty()}";
  }
}

void main() {
  MainModule();

  final http = injector.get<Http>();
  print(http.doHttp());
}
