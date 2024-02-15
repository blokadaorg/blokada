import 'dart:convert';

import 'package:unique_names_generator/unique_names_generator.dart' as names;

import '../../persistence/persistence.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../api/api.dart';
import '../api/prod.dart';
import '../profile/json.dart';
import '../profile/profile.dart';
import 'device.dart';
import 'json.dart';

final _trace = dep<TraceFactory>();
final _persistence = dep<PersistenceService>();
final _profile = dep<ProfileActor>();

final _generator = names.UniqueNamesGenerator(
  config: names.Config(
    length: 1,
    seperator: " ",
    style: names.Style.capital,
    dictionaries: [names.animals],
  ),
);

const _keyDevice = "fsm:device:device";

Future<JsonDevice?> _getPersistedDevice(void _) async {
  final trace = _trace.newTrace("ProdDeviceActor", "persistedDevice");
  final json = await _persistence.load(trace, _keyDevice);
  if (json == null) return null;
  return JsonDevice.fromJson(jsonDecode(json));
}

Future<void> _savePersistedDevice(JsonDevice device) async {
  final trace = _trace.newTrace("ProdDeviceActor", "savePersistedDevice");
  final json = jsonEncode(device.toJson());
  await _persistence.saveString(trace, _keyDevice, json);
}

Future<List<JsonDevice>> _getDevices(Act act) async {
  final actor = ProdApiActor(act, HttpRequest(ApiEndpoint.getDevices));
  final json = (await actor.waitForState(ApiStates.success)).result!;
  return DeviceJson().devices(json);
}

Future<ProfileId> _createProfile(Act act, JsonProfilePayload payload) async {
  final actor = ProdApiActor(
    act,
    HttpRequest(
      ApiEndpoint.postProfile,
      payload: jsonEncode(payload.toJson()),
    ),
  );
  final json = (await actor.waitForState(ApiStates.success)).result!;
  return JsonProfile.fromJson(jsonDecode(json)).profileId;
}

Future<JsonDevice> _createDevice(Act act, JsonDevicePayload payload) async {
  final actor = ProdApiActor(
    act,
    HttpRequest(
      ApiEndpoint.postDevice,
      payload: jsonEncode(payload.toJson()),
    ),
  );
  final json = (await actor.waitForState(ApiStates.success)).result!;
  return JsonDevice.fromJson(jsonDecode(json)["device"]);
}

class ProdDeviceActor extends DeviceActor {
  ProdDeviceActor(Act act)
      : super(
          actionPersistedDevice: _getPersistedDevice,
          actionSavePersistedDevice: _savePersistedDevice,
          actionDevices: (_) => _getDevices(act),
          actionCreateProfile: (payload) async => _createProfile(act, payload),
          actionCreateDevice: (payload) async => _createDevice(act, payload),
          actionGenerateDeviceAlias: (_) async => _generator.generate(),
        ) {
    addOnState(DeviceStates.deviceSelected, "selectProfile", (state, c) async {
      final profileId = c.selected!.profileId;
      await _profile.enter(ProfileStates.unselectProfile);
      await _profile.selectProfile(profileId);
    });
  }
}
