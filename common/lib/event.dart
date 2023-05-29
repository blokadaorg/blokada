import 'util/trace.dart';

enum CommonEvent {
  stageModalChanged,
  stageForegroundChanged,
  stageRouteChanged,
  accountChanged,
  accountIdChanged,
  accountTypeChanged,
  appStatusChanged,
  plusKeypairChanged,
  plusLeaseChanged,
  deviceConfigChanged
}

mixin EventBus {
  Future<void> onEvent(Trace trace, CommonEvent event);
}
