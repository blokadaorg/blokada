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
  when(family.phase).thenReturn(FamilyPhase.parentHasDevices);
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
        alias: "Parent",
        lists: [],
        safeSearch: false,
      ),
      stats: _mockStats,
      thisDevice: true,
      linked: false,
    ),
    FamilyDevice(
      device: JsonDevice(
        deviceTag: "abcd",
        alias: "Alva",
        mode: JsonDeviceMode.on,
        retention: "24h",
        profileId: "2",
      ),
      profile: JsonProfile(
        profileId: "2",
        alias: "Child",
        lists: [],
        safeSearch: false,
      ),
      stats: _mockStats2,
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
    350,
    340,
    280,
    330,
    325,
    300,
    250,
    80,
    100,
    50,
    20,
    0,
    0,
    0,
    0,
    30,
    90,
    70,
    90,
    110,
    290,
    190,
    230,
    250
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
    6,
    3,
    2,
    0,
    0,
    0,
    0,
    0,
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

UiStats _mockStats2 = UiStats(
  totalAllowed: 723832,
  totalBlocked: 74384,
  allowedHistogram: [
    13,
    24,
    48,
    68,
    88,
    60,
    40,
    20,
    34,
    54,
    94,
    0,
    0,
    0,
    0,
    40,
    60,
    80,
    230,
    133,
    23,
    43,
    68,
    33
  ],
  blockedHistogram: [
    1,
    2,
    7,
    3,
    2,
    0,
    3,
    3,
    3,
    0,
    0,
    0,
    0,
    3,
    3,
    8,
    4,
    2,
    3,
    3,
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
