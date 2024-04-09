// import 'package:common/family/devices.dart';
//
// class MockDevices extends HandleVia<FamilyDevices> {
//   @override
//   FamilyDevices defaults() => FamilyDevices([
//         FamilyDevice(
//           deviceName: "Alva",
//           deviceDisplayName: "Alva",
//           stats: MockUiStats().defaults(),
//           thisDevice: false,
//           enabled: true,
//           configured: true,
//         ),
//         FamilyDevice(
//           deviceName: "Bobby",
//           deviceDisplayName: "This device",
//           stats: MockUiStats().defaults(),
//           thisDevice: true,
//           enabled: true,
//           configured: true,
//         ),
//       ], true);
//
//   @override
//   Future<FamilyDevices> get() async => defaults();
// }
//
// class MockUiStats extends HandleVia<UiStats> {
//   @override
//   UiStats defaults() => UiStats(
//         totalAllowed: 723832,
//         totalBlocked: 74384,
//         allowedHistogram: [
//           23,
//           44,
//           78,
//           33,
//           12,
//           0,
//           23,
//           123,
//           3,
//           0,
//           0,
//           0,
//           0,
//           134,
//           38,
//           83,
//           43,
//           27,
//           23,
//           233,
//           23,
//           33,
//           48,
//           23
//         ],
//         // allowedHistogram: [
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   0,
//         //   30,
//         //   50,
//         //   120,
//         //   70
//         // ],
//         blockedHistogram: [
//           3,
//           4,
//           7,
//           3,
//           2,
//           0,
//           3,
//           13,
//           3,
//           0,
//           0,
//           0,
//           0,
//           13,
//           3,
//           8,
//           4,
//           2,
//           3,
//           23,
//           3,
//           3,
//           4,
//           3
//         ],
//         toplist: [],
//         avgDayTotal: 100,
//         avgDayAllowed: 80,
//         avgDayBlocked: 20,
//         latestTimestamp: DateTime.now().millisecondsSinceEpoch,
//       );
//
//   @override
//   Future<UiStats> get() async => defaults();
// }
