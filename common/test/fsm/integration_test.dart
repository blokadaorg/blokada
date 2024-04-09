// import 'package:common/via/fsm/device/device.dart';
// import 'package:common/injectant/device/json.dart';
// import 'package:common/injectant/profile/json.dart';
// import 'package:common/via/fsm/profile/profile.dart';
// import 'package:flutter_test/flutter_test.dart';
//
// import '../tools.dart';
//
// void main() {
//   group("integration", () {
//     test("device", () async {
//       await withTrace((trace) async {
//         final device = DeviceActor(
//           actionPersistedDevice: (_) async {
//             return JsonDevice(
//               deviceTag: "thisDevice",
//               alias: "thisAlias",
//               paused: false,
//               retention: "24h",
//               profileId: "thisProfileId",
//             );
//           },
//           actionSavePersistedDevice: (_) async {},
//           actionDevices: (_) async => [
//             JsonDevice(
//               deviceTag: "thisDevice",
//               alias: "thisAlias",
//               paused: false,
//               retention: "24h",
//               profileId: "thisProfileId",
//             ),
//             JsonDevice(
//               deviceTag: "otherDevice",
//               alias: "alias",
//               paused: false,
//               retention: "24h",
//               profileId: "otherProfileId",
//             ),
//           ],
//           actionCreateProfile: (_) async => throw Exception("Nope"),
//           actionCreateDevice: (_) async => throw Exception("Nope"),
//           actionGenerateDeviceAlias: (_) async => "mockAlias",
//         );
//
//         final profile = ProfileActor(
//           actionProfiles: (_) async => [
//             JsonProfile(
//               profileId: "thisProfileId",
//               alias: "alias",
//               lists: ["list1", "list2"],
//               safeSearch: true,
//             )
//           ],
//           actionUpdateConfig: (_) async {},
//         );
//
//         device.addOnState(DeviceStates.deviceSelected, "selectProfile",
//             (state, c) async {
//           final profileId = c.selected!.profileId;
//           await profile.enter(ProfileStates.unselectProfile);
//           await profile.selectProfile(profileId);
//         });
//
//         await device.waitForState(DeviceStates.ready);
//
//         final c = await profile.waitForState(ProfileStates.ready);
//         expect(c.selected, null);
//
//         await device.selectDevice("thisDevice");
//         await device.waitForState(DeviceStates.deviceSelected);
//         await profile.waitForState(ProfileStates.profileSelected);
//       });
//     });
//   });
// }
