import '../common/model.dart';
import '../json/json.dart';

class JsonFamilyDevices {
  late List<String> devices;

  JsonFamilyDevices({required this.devices});

  JsonFamilyDevices.fromJson(Map<String, dynamic> json) {
    try {
      devices = <String>[];
      json['devices'].forEach((v) {
        devices.add(v);
      });
    } on TypeError catch (e) {
      throw JsonError(json, e);
    } on NoSuchMethodError catch (e) {
      throw JsonError(json, e);
    }
  }

  JsonFamilyDevices.fromList(List<FamilyDevice> devices) {
    this.devices = devices.map((e) => e.deviceName).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['devices'] = devices;
    return data;
  }
}
