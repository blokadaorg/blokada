// import 'package:common/core/core.dart';
// import 'package:common/platform/device/device.dart';
// import 'package:common/platform/env/env.dart';
// import 'package:common/platform/journal/journal.dart';
// import 'package:common/platform/journal/json.dart';
// import 'package:common/platform/stage/stage.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:mockito/annotations.dart';
// import 'package:mockito/mockito.dart';
//
// import '../../tools.dart';
// import 'fixtures.dart';
// @GenerateNiceMocks([
//   MockSpec<JournalStore>(),
//   MockSpec<JournalJson>(),
//   MockSpec<Scheduler>(),
//   MockSpec<StageStore>(),
//   MockSpec<EnvStore>(),
//   MockSpec<DeviceStore>(),
// ])
// import 'journal_test.mocks.dart';
//
// void main() {
//   group("store", () {
//     test("willGroupEntriesByRequests", () async {
//       await withTrace((m) async {
//         Core.register<StageStore>(MockStageStore());
//         Core.register<DeviceStore>(MockDeviceStore());
//
//         final timer = MockScheduler();
//         Core.register<Scheduler>(timer);
//
//         final env = MockEnvStore();
//         when(env.deviceName).thenReturn("deviceName");
//         Core.register<EnvStore>(env);
//
//         final json = MockJournalJson();
//         when(json.getEntries(any))
//             .thenAnswer((_) => Future.value(fixtureJournalEntries));
//         Core.register<JournalJson>(json);
//
//         final subject = JournalStore();
//         await subject.fetch(m);
//
//         expect(subject.filteredEntries.length, 2);
//         expect(subject.filteredEntries[0].requests, 3);
//         expect(subject.filteredEntries[0].domainName, "app-measurement.com");
//         expect(subject.filteredEntries[1].requests, 4);
//         expect(subject.filteredEntries[1].domainName, "latency.discord.media");
//       });
//     });
//
//     test("willFilterEntries", () async {
//       await withTrace((m) async {
//         Core.register<StageStore>(MockStageStore());
//         Core.register<DeviceStore>(MockDeviceStore());
//
//         final timer = MockScheduler();
//         Core.register<Scheduler>(timer);
//
//         final env = MockEnvStore();
//         when(env.deviceName).thenReturn("deviceName");
//         Core.register<EnvStore>(env);
//
//         final json = MockJournalJson();
//         when(json.getEntries(any))
//             .thenAnswer((_) => Future.value(fixtureJournalEntries));
//         Core.register<JournalJson>(json);
//
//         final subject = JournalStore();
//         await subject.fetch(m);
//
//         expect(subject.filteredEntries.length, 2);
//
//         // Search term (not existing)
//         await subject.updateFilter(m, searchQuery: "foo");
//
//         expect(subject.filteredEntries.length, 0);
//
//         // Search term (existing)
//         await subject.updateFilter(m, searchQuery: "discord");
//
//         expect(subject.filteredEntries.length, 1);
//
//         // Device name (need to reset previous filter)
//         await subject.updateFilter(m,
//             searchQuery: "", deviceName: "deviceName");
//
//         expect(subject.filteredEntries.length, 2);
//
//         // Blocked only
//         await subject.updateFilter(
//           m,
//           searchQuery: "",
//           deviceName: "",
//           showOnly: JournalFilterType.blocked,
//         );
//
//         expect(subject.filteredEntries.length, 1);
//         expect(subject.filteredEntries.first.domainName, "app-measurement.com");
//
//         // Passed only
//         await subject.updateFilter(
//           m,
//           showOnly: JournalFilterType.passed,
//         );
//
//         expect(subject.filteredEntries.length, 1);
//         expect(
//             subject.filteredEntries.first.domainName, "latency.discord.media");
//       });
//     });
//
//     test("willSortEntries", () async {
//       await withTrace((m) async {
//         Core.register<StageStore>(MockStageStore());
//         Core.register<DeviceStore>(MockDeviceStore());
//
//         final timer = MockScheduler();
//         Core.register<Scheduler>(timer);
//
//         final env = MockEnvStore();
//         when(env.deviceName).thenReturn("deviceName");
//         Core.register<EnvStore>(env);
//
//         final json = MockJournalJson();
//         when(json.getEntries(any))
//             .thenAnswer((_) => Future.value(fixtureJournalEntries));
//         Core.register<JournalJson>(json);
//
//         final subject = JournalStore();
//         await subject.fetch(m);
//
//         // Sort by newest first
//         await subject.updateFilter(m, sortNewestFirst: true);
//
//         expect(subject.filteredEntries.first.requests, 3);
//         expect(subject.filteredEntries.first.domainName, "app-measurement.com");
//
//         // Sort by most requests first
//         await subject.updateFilter(m, sortNewestFirst: false);
//
//         expect(subject.filteredEntries.first.requests, 4);
//         expect(
//             subject.filteredEntries.first.domainName, "latency.discord.media");
//       });
//     });
//
//     test("willRefreshWhenNeeded", () async {
//       await withTrace((m) async {
//         Core.register<DeviceStore>(MockDeviceStore());
//
//         final json = MockJournalJson();
//         Core.register<JournalJson>(json);
//
//         final timer = MockScheduler();
//         Core.register<Scheduler>(timer);
//
//         final stage = MockStageStore();
//         when(stage.route)
//             .thenReturn(StageRouteState.init().newTab(StageTab.activity));
//         Core.register<StageStore>(stage);
//
//         final subject = JournalStore();
//         mockAct(subject);
//         verifyNever(json.getEntries(any));
//
//         // Won't refresh if not enabled
//         await subject.updateJournalFreq(m);
//         verifyNever(json.getEntries(any));
//
//         // But will, if enabled
//         await subject.enableRefresh(m);
//         await subject.updateJournalFreq(m);
//         verify(json.getEntries(any));
//       });
//     });
//   });
// }
