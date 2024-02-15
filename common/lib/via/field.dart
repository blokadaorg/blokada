// import 'package:common/fsm/api/api.dart';
// import 'package:common/fsm/device/device.dart';
// import 'package:common/fsm/profile/json.dart';
//
// import 'apivessel.dart';
// import 'device/json.dart';
// import 'via.dart';
//
// enum DevicesState { reload, fatal, thisDevice, deviceSelected }
//
// class ViaRegistry<T> {
//   static ViaReadResolver<T, dynamic> resolveRead<T>(dynamic context) {
//     //return [];
//   }
//
//   static List<ViaReadWriteResolver<T, dynamic>> resolveWrite<T>(dynamic tag) {
//     return [];
//   }
// }
//
//
//
// class _GeneratedDevices with DevicesStateField {
//   _GeneratedDevices() {
//     final devicesResolver = ViaRegistry.resolveRead("string");
//     _devices.reader = () async {
//       return await devicesResolver.read("string");
//     };
//     _devices.writer = (value) async {
//       final resolvers = ViaRegistry.resolveWrite("string");
//       for (final resolver in resolvers) {
//         await resolver.write("string", value);
//       }
//     };
//     }
//   }
// }
//
// @Operation()
// mixin DevicesStateField {
//   @ReadWith(Api, context: ApiEndpoint.getDevices)
//   @CreateWith(Api, context: ApiEndpoint.postDevice)
//   //@Valise(ApiEndpoint.putDevice)
//   final _devices = Via.listable<JsonDevice>();
//
//   // @ViaApi(AnotherEndpoint)
//   final _profiles = Via.listable<JsonProfile>();
//
//   // @ViaPersistence("fsm:device")
//   //@ReadWith(Persistence)
//   final _thisDevice = Via.writeable<JsonDevice?>();
//
//   // @ViaGenerator("deviceAlias")
//   @ViaTags("generator", {"tag": "deviceAlias"})
//   final _nextAlias = Via.readable<DeviceAlias>();
//
//   final _selected = Via.writeable<JsonDevice?>();
//   final _selectedProfile = Via.writeable<JsonProfile?>();
//
//   late Map<DevicesState, Function()> states = {
//     DevicesState.thisDevice: _checkThisDevice,
//     DevicesState.deviceSelected: _deviceSelected,
//   };
//
//   @override
//   Future<DevicesState> calculate() async {
//     // machine.enter(DeviceStates.thisDevice);
//   }
//
//   _checkThisDevice() async {
//     final d = await _thisDevice.get();
//     if (d == null) {
//       // This device is not registered, create a profile and a device
//       // final profile = JsonProfile.fresh()
//       // final added = await _profiles.add(profile);
//       // final device = JsonDevice.fresh(
//       //   profileId: added.profileId,
//       //   alias: await _nextAlias.get(),
//       // );
//       // final _thisDevice.set(await _devices.add(device));
//       // .. or _checkThisDevice again to confirm <- maybe less requests
//     }
//   }
//
//   selectDevice(DeviceTag tag) async {
//     // find device in devices
//     // find corresponding profile
//     // both selected
//     // change in selected profile causes refresh of Filter?
//   }
// }
