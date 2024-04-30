import 'package:common/common/model.dart';
import 'package:common/dragon/family/devices.dart';
import 'package:common/dragon/family/family.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/util/di.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<FamilyStore>(),
  MockSpec<ProfileController>(),
])
import 'mocked-deps.mocks.dart';

attachMockedDeps() {
  dep.allowReassignment = true;
  final family = MockFamilyStore();
  when(family.phase).thenReturn(FamilyPhase.fresh);
  when(family.devices).thenReturn(FamilyDevices([
    FamilyDevice(
      device: JsonDevice(
        deviceTag: "abc",
        alias: "Device 1",
        mode: JsonDeviceMode.on,
        retention: "24h",
        profileId: "1",
      ),
      profile: JsonProfile(
        profileId: "1",
        alias: "Profile 1",
        lists: [],
        safeSearch: false,
      ),
      stats: UiStats.empty(),
      thisDevice: true,
      linked: false,
    ),
    FamilyDevice(
      device: JsonDevice(
        deviceTag: "abcd",
        alias: "Device 2",
        mode: JsonDeviceMode.on,
        retention: "24h",
        profileId: "2",
      ),
      profile: JsonProfile(
        profileId: "2",
        alias: "Profile 2",
        lists: [],
        safeSearch: false,
      ),
      stats: UiStats.empty(),
      thisDevice: false,
      linked: true,
    ),
  ], false));
  depend<FamilyStore>(family);

  final profile = MockProfileController();
  when(profile.get(any)).thenReturn(JsonProfile(
      profileId: "1", alias: "Profile X", lists: [], safeSearch: false));
  depend<ProfileController>(profile);
}

UiStats _mockStats = UiStats(
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
