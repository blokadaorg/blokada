import 'package:common/common/model.dart';
import 'package:common/dragon/customlist/api.dart';
import 'package:common/logger/logger.dart';
import 'package:common/util/di.dart';

class CustomListController {
  late final _customlist = dep<CustomListApi>();

  String? profileId;

  List<String> denied = [];
  List<String> allowed = [];

  Function onChange = () {};

  // Has to be called before other methods
  setProfileId(String id, Marker m) async {
    if (profileId == id) return;
    profileId = id;
    denied = [];
    allowed = [];
    await fetch(m);
  }

  fetch(Marker m) async {
    final entries = await _customlist.fetchForProfile(profileId!, m);
    denied = entries
        .where((e) => e.action == JsonCustomListAction.block)
        .map((e) => e.domainName)
        .toList();
    denied.sort();

    allowed = entries
        .where((e) => e.action == JsonCustomListAction.allow)
        .map((e) => e.domainName)
        .toList();
    allowed.sort();
    onChange();
  }

  _allow(String domain, Marker m) async {
    allowed.add(domain);
    onChange();
    await _customlist.add(
        profileId!,
        JsonCustomList(
          domainName: domain,
          action: JsonCustomListAction.allow,
          wildcard: false, // Ignored
        ),
        m);
  }

  _deny(String domain, Marker m) async {
    denied.add(domain);
    onChange();
    await _customlist.add(
        profileId!,
        JsonCustomList(
          domainName: domain,
          action: JsonCustomListAction.block,
          wildcard: false, // Ignored
        ),
        m);
  }

  _delete(String domain, Marker m) async {
    allowed.remove(domain);
    denied.remove(domain);
    onChange();
    await _customlist.delete(
        profileId!,
        JsonCustomList(
          domainName: domain,
          action: JsonCustomListAction.allow, // Ignored
          wildcard: false, // Ignored
        ),
        m);
  }

  addOrRemove(String domain, Marker m, {required bool gotBlocked}) async {
    if (contains(domain)) {
      await _delete(domain, m);
    } else if (gotBlocked) {
      await _allow(domain, m);
    } else {
      await _deny(domain, m);
    }
    await fetch(m);
    onChange();
  }

  bool contains(String domain) {
    // todo: wildcard?
    return allowed.contains(domain) || denied.contains(domain);
  }
}
