import 'package:mobx/mobx.dart';

import '../util/di.dart';
import '../util/trace.dart';
import 'channel.pg.dart';

part 'env.g.dart';

class EnvStore = EnvStoreBase with _$EnvStore;

abstract class EnvStoreBase with Store, Traceable {
  @observable
  String? accountId;

  @observable
  int accountIdChanges = 0;

  @observable
  String? deviceTag;

  @observable
  String? deviceName;

  @observable
  String? userAgent;

  @computed
  String get currentUser {
    final id = accountId;
    if (id == null) {
      throw Exception("No account ID set yet");
    }
    return id;
  }

  @computed
  String get currentDevice {
    final tag = deviceTag;
    if (tag == null) {
      throw Exception("No device tag set yet");
    }
    return tag;
  }

  @action
  Future<void> setAccountId(Trace parentTrace, String value) async {
    return await traceWith(parentTrace, "setAccountId", (trace) async {
      if (value == accountId) {
        return;
      }

      if (accountId != null) {
        accountIdChanges += 1;
      }

      accountId = value;
      trace.addEvent("accountId changed");
    });
  }

  @action
  Future<void> setDeviceTag(Trace parentTrace, String value) async {
    return await traceWith(parentTrace, "setDeviceTag", (trace) async {
      if (value == deviceTag) {
        return;
      }

      deviceTag = value;
      trace.addEvent("deviceTag changed");
    });
  }

  @action
  Future<void> setUserAgent(Trace parentTrace, String value) async {
    return await traceWith(parentTrace, "setUserAgent", (trace) async {
      userAgent = value;
    });
  }

  @action
  Future<void> setDeviceName(Trace parentTrace, String value) async {
    return await traceWith(parentTrace, "setDeviceName", (trace) async {
      deviceName = value;
    });
  }
}

class EnvBinder with Traceable {
  late final _store = di<EnvStore>();
  late final _ops = di<EnvOps>();

  EnvBinder() {
    _getUserAgentFromChannel();
    _onDeviceName();
  }

  _getUserAgentFromChannel() async {
    await traceAs("getUserAgentFromChannel", (trace) async {
      final userAgent = await _ops.doGetUserAgent();
      await _store.setUserAgent(trace, userAgent);
    });
  }

  _onDeviceName() async {
    await traceAs("onDeviceName", (trace) async {
      final payload = await _ops.doGetEnvPayload();
      await _store.setDeviceName(trace, payload.deviceName);
    });
  }
}

Future<void> init() async {
  di.registerSingleton<EnvOps>(EnvOps());
  di.registerSingleton<EnvStore>(EnvStore());
  EnvBinder();
}
