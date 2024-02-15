import 'package:vistraced/via.dart';

import '../../fsm/device/json.dart';
import '../actions.dart';

part 'persistence.g.dart';

@Module([
  ViaMatcher<String>(ViaPersistence<String>, of: ofPersistence),
  ViaMatcher<JsonDevice?>(ViaPersistence<JsonDevice?>, of: ofPersistence),
])
class PersistenceModule extends _$PersistenceModule {}

@Injected()
class ViaPersistence<T> extends HandleVia<T> {
  @override
  Future<T> get() async {
    if (T == String) return "3" as T;
    throw Exception("not implemented");
  }

  @override
  Future<void> set(T value) async {}
}
