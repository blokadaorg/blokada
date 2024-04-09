import 'package:via/via.dart';

part 'example2.g.dart';

const api = "api";
const persistence = "persistence";

@Module([
  ViaMatcher<String>(ViaPersistence<String>, of: persistence),
  ViaMatcher<List<String>>(ListViaApi, of: api),
  ViaMatcher<String>(AddViaApi, of: api),
])
class PersistenceModule extends _$PersistenceModule {}

@Injected()
class ViaPersistence<T> extends HandleVia<T> {
  @override
  Future<T> get() async {
    if (T == String) return "$context: 0" as T;
    throw Exception("not implemented");
  }
}

@Injected()
class ListViaApi extends HandleVia<List<String>> {
  @override
  Future<List<String>> get() async {
    return ["1", "2", "3"];
  }
}

@Injected()
class AddViaApi extends HandleVia<String> {}

@Injected()
class UsingPersistence {
  @MatcherSpec(of: persistence, ctx: "some context")
  final _via = Via.as<String>();

  @MatcherSpec(of: api)
  final _list = Via.list<String>();

  Future<String> doSomething() async {
    return "${await _via.fetch()} ${(await _list.fetch()).join(", ")}";
  }
}

@Module([SimpleMatcher(UsingPersistence)])
class MainModule extends _$MainModule {}

@Bootstrap(ViaAct(
  scenario: "prod",
  platform: ViaPlatform.ios,
  flavor: "main",
))
class MainBootstrap {}

void main() async {
  PersistenceModule();
  MainModule();
  injector.inject();

  final us = injector.get<UsingPersistence>();
  print(await us.doSomething());
}
