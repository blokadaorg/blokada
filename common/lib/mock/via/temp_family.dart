import 'package:collection/collection.dart';
import 'package:common/app/app.dart';
import 'package:common/family/devices.dart';
import 'package:common/family/family.dart';
import 'package:common/perm/channel.pg.dart';
import 'package:mobx/mobx.dart';
import 'package:vistraced/via.dart';

import '../../app/channel.pg.dart';
import '../../common/model.dart';
import '../../lock/lock.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';

part 'temp_family.g.dart';

@Module([
  ViaMatcher<StageModal?>(TempStageModal),
  ViaMatcher<bool>(TempStageReady, of: "stage"),
  ViaMatcher<AppStatus>(TempAppStatus),
  ViaMatcher<FamilyPhase>(TempFamilyPhase),
  ViaMatcher<FamilyDevices>(TempFamilyDevices),
  ViaMatcher<String>(TempStageRoute, of: "stage"),
  ViaMatcher<void>(TempFamilyOpenPerms, of: "familyOpenPerms"),
])
class TempModule extends _$TempModule {}

@Injected(onlyVia: true)
class TempFamilyOpenPerms extends HandleVia<void> with TraceOrigin {
  late final _ops = dep<PermOps>();

  @override
  Future<void> set(void value) async {
    _ops.doOpenSettings();
  }
}

@Injected(onlyVia: true)
class TempStageModal extends HandleVia<StageModal?> with TraceOrigin {
  late final _stage = dep<StageStore>();

  TempStageModal() {
    _stage.addOnValue(routeChanged, (trace, route) => dirty());
  }

  @override
  StageModal? defaults() => _stage.route.modal;

  @override
  Future<StageModal?> get() async {
    return _stage.route.modal;
  }

  @override
  Future<void> set(StageModal? value) async {
    await traceAs("actualmodal", (trace) async {
      if (value == null) {
        await _stage.dismissModal(trace);
      } else {
        await _stage.showModal(trace, value);
      }
    });
  }
}

@Injected(onlyVia: true)
class TempStageReady extends HandleVia<bool> with TraceOrigin {
  late final _stage = dep<StageStore>();

  TempStageReady() {
    _stage.addOnValue(routeChanged, (trace, route) => dirty());
  }

  @override
  bool defaults() => _stage.isReady;

  @override
  Future<bool> get() async {
    return _stage.isReady;
  }
}

@Injected(onlyVia: true)
class TempAppStatus extends HandleVia<AppStatus> with TraceOrigin {
  late final _app = dep<AppStore>();

  TempAppStatus() {
    _app.addOn(appStatusChanged, (trace) => dirty());
  }

  @override
  AppStatus defaults() => _app.status;

  @override
  Future<AppStatus> get() async {
    return _app.status;
  }
}

@Injected(onlyVia: true)
class TempFamilyPhase extends HandleVia<FamilyPhase> with TraceOrigin {
  late final _family = dep<FamilyStore>();

  TempFamilyPhase() {
    reaction((_) => _family.phase, (phase) {
      print("family phase reaction called");
      dirty();
    });
  }

  @override
  FamilyPhase defaults() => _family.phase;

  @override
  Future<FamilyPhase> get() async {
    return _family.phase;
  }
}

@Injected(onlyVia: true)
class TempFamilyDevices extends HandleVia<FamilyDevices> with TraceOrigin {
  late final _family = dep<FamilyStore>();

  TempFamilyDevices() {
    reaction((_) => _family.devices, (devices) {
      dirty();
    });
  }

  @override
  FamilyDevices defaults() => _family.devices;

  @override
  Future<FamilyDevices> get() async {
    return _family.devices;
  }
}

@Injected(onlyVia: true)
class TempStageRoute extends HandleVia<String> with TraceOrigin {
  late final _stage = dep<StageStore>();

  TempStageRoute() {
    _stage.addOnValue(routeChanged, (trace, route) => dirty());
  }

  @override
  String defaults() => _stage.route.route.path;

  @override
  Future<String> get() async {
    return _stage.route.route.path;
  }
}
