part of 'perm.dart';

class DnsPerm extends AsyncValue<bool> {
  DnsPerm() {
    load = (Marker m) async => false;
  }
}
