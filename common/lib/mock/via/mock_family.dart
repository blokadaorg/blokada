import 'package:collection/collection.dart';
import 'package:common/family/devices.dart';
import 'package:vistraced/via.dart';

import '../../app/channel.pg.dart';
import '../../common/model.dart';
import '../../lock/lock.dart';
import '../../stage/channel.pg.dart';
import '../../util/di.dart';

part 'mock_family.g.dart';

@Module([
  ViaMatcher<FamilyPhase>(MockFamilyPhase),
  ViaMatcher<FamilyDevices>(MockDevices),
  ViaMatcher<AppStatus>(MockAppStatus),
  ViaMatcher<StageModal?>(MockStageModal),
  ViaMatcher<String>(MockStageRoute, of: "stage"),
  ViaMatcher<String>(MockSelectedDevice, of: "family"),
  ViaMatcher<void>(EmptyCall<void>, of: "familyUnlink"),
  ViaMatcher<void>(EmptyCall<void>, of: "familyOpenPerms"),
  ViaMatcher<LockStore>(PassLockStore),
  ViaMatcher<bool>(MockStageReady, of: "stage"),
  ViaMatcher<UiStats>(MockUiStats),
])
class MockModule extends _$MockModule {}

@Injected()
class PassLockStore extends MockCommandHandler<LockStore> {
  PassLockStore() : super("lock", dep<LockStore>());

  @override
  LockStore valueFromCommand(String cmd) => throw UnimplementedError();
}

@Injected()
class MockStageReady extends MockCommandHandler<bool> {
  MockStageReady() : super("ready", true);

  @override
  bool valueFromCommand(String cmd) => cmd == "1";
}

@Injected()
class MockSelectedDevice extends MockCommandHandler<String> {
  MockSelectedDevice() : super("selectedDevice", "device1");

  @override
  String valueFromCommand(String cmd) => cmd;
}

@Injected()
class MockAppStatus extends MockCommandHandler<AppStatus> {
  MockAppStatus() : super("appstatus", AppStatus.paused);

  @override
  AppStatus valueFromCommand(String cmd) =>
      AppStatus.values.firstWhere((e) => e.name == cmd);
}

@Injected()
class MockStageModal extends MockCommandHandler<StageModal?> {
  MockStageModal() : super("modal", null);

  @override
  StageModal? valueFromCommand(String cmd) =>
      StageModal.values.firstWhereOrNull((e) => e.name == cmd);
}

@Injected()
class MockStageRoute extends MockCommandHandler<String> {
  MockStageRoute() : super("route", "home");

  @override
  String valueFromCommand(String cmd) => cmd;
}

@Injected()
class MockFamilyPhase extends MockCommandHandler<FamilyPhase> {
  //MockFamilyPhase() : super("phase", FamilyPhase.starting);
  MockFamilyPhase() : super("phase", FamilyPhase.parentHasDevices);

  @override
  FamilyPhase valueFromCommand(String cmd) =>
      FamilyPhase.values.firstWhere((e) => e.name == cmd);
}

final mockCommands = CommandBasedMockBehavior();

abstract class MockCommandHandler<T> extends HandleVia<T> {
  final String name;
  T current;

  MockCommandHandler(this.name, this.current) {
    mockCommands.handlers[name] = (cmd) async {
      await updateFromCommand(cmd);
    };
  }

  @override
  T defaults() => current;

  @override
  Future<T> get() async => current;

  @override
  Future<void> set(T value) async {
    current = value;
    dirty();
  }

  T valueFromCommand(String cmd);

  updateFromCommand(String cmd) async {
    try {
      if (cmd == "null") throw Exception("will try setting null below");
      await set(valueFromCommand(cmd));
    } catch (_) {
      if (null is T) {
        await set(null as T);
      } else {
        rethrow;
      }
    }
    dirty();
  }
}

class CommandBasedMockBehavior {
  final Map<String, Function(String)> handlers = {};

  handleCommand(String command) async {
    final parts = command.split(" ");
    final handler = handlers[parts[0]];
    if (handler != null) {
      await handler(parts.skip(1).join(" "));
    } else {
      throw Exception("No via mock handler for command: $command");
    }
  }
}

@Injected()
class EmptyCall<T> extends HandleVia<T> {
  @override
  Future<void> set(T value) async {}
}

@Injected()
class MockDevices extends HandleVia<FamilyDevices> {
  @override
  FamilyDevices defaults() => FamilyDevices([
        FamilyDevice(
          deviceName: "Alva",
          deviceDisplayName: "Alva",
          stats: MockUiStats().defaults(),
          thisDevice: false,
          enabled: true,
          configured: true,
        ),
        FamilyDevice(
          deviceName: "Bobby",
          deviceDisplayName: "This device",
          stats: MockUiStats().defaults(),
          thisDevice: true,
          enabled: true,
          configured: true,
        ),
      ], true);

  @override
  Future<FamilyDevices> get() async => defaults();
}

@Injected()
class MockUiStats extends HandleVia<UiStats> {
  @override
  UiStats defaults() => UiStats(
        totalAllowed: 723832,
        totalBlocked: 74384,
        allowedHistogram: [
          23,
          44,
          78,
          33,
          12,
          0,
          23,
          123,
          3,
          0,
          0,
          0,
          0,
          134,
          38,
          83,
          43,
          27,
          23,
          233,
          23,
          33,
          48,
          23
        ],
        // allowedHistogram: [
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   0,
        //   30,
        //   50,
        //   120,
        //   70
        // ],
        blockedHistogram: [
          3,
          4,
          7,
          3,
          2,
          0,
          3,
          13,
          3,
          0,
          0,
          0,
          0,
          13,
          3,
          8,
          4,
          2,
          3,
          23,
          3,
          3,
          4,
          3
        ],
        toplist: [],
        avgDayTotal: 100,
        avgDayAllowed: 80,
        avgDayBlocked: 20,
        latestTimestamp: DateTime.now().millisecondsSinceEpoch,
      );

  @override
  Future<UiStats> get() async => defaults();
}
