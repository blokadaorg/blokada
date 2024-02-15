import 'package:vistraced/via.dart';

import '../common/model.dart';
import 'actions.dart';

part 'via.g.dart';

@Injected()
class DirectVia<T> extends HandleVia<T> {
  //T current;

  @override
  Future<T> get() async => null as T;

  @override
  Future<void> set(T value) async {}
}

@Module([
  ViaMatcher<UserFilterConfig>(DirectVia<UserFilterConfig>, of: ofDirect),
])
class DeviceFilterLink extends _$DeviceFilterLink {}
