import 'package:mobx/mobx.dart';

import '../util/di.dart';
import '../util/trace.dart';
import 'channel.pg.dart';

part 'env.g.dart';

class EnvStore = EnvStoreBase with _$EnvStore;

abstract class EnvStoreBase with Store, Traceable, Dependable {
  late final _ops = di<EnvOps>();

  @override
  attach() {
    depend<EnvOps>(EnvOps());
    depend<EnvStore>(this as EnvStore);
  }

  @observable
  String? accountId;

  @observable
  int accountIdChanges = 0;

  @observable
  String? deviceTag;

  @observable
  String? deviceName;

  @observable
  String? devicePublicKey;

  @computed
  String get currentUser {
    final id = accountId;
    if (id == null) {
      throw Exception("No account ID set yet");
    }
    return id;
  }

  @computed
  String get currentDeviceTag {
    final tag = deviceTag;
    if (tag == null) {
      throw Exception("No device tag set yet");
    }
    return tag;
  }

  @computed
  String get currentDevicePublicKey {
    final key = devicePublicKey;
    if (key == null) {
      throw Exception("No device public key set yet");
    }
    return key;
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
  Future<void> syncDeviceName(Trace parentTrace) async {
    return await traceWith(parentTrace, "setDeviceName", (trace) async {
      final payload = await _ops.doGetEnvPayload();
      deviceName = payload.deviceName;
    });
  }

  @action
  Future<void> setDevicePublicKey(Trace parentTrace, String value) async {
    return await traceWith(parentTrace, "setDevicePublicKey", (trace) async {
      devicePublicKey = value;
    });
  }
}
