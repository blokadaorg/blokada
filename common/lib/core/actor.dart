part of 'core.dart';

mixin Actor {
  bool _created = false;
  bool _started = false;

  @nonVirtual
  void create(Marker m) {
    //if (_created) throw Exception("Actor already created");
    if (_created) return;
    _created = true;

    onCreate(m);
  }

  @nonVirtual
  Future<void> start(Marker m) async {
    //if (_started) throw Exception("Actor already started");
    if (_started) return;
    _started = true;

    await onStart(m);
  }

  Future<void> onCreate(Marker m) async {}
  Future<void> onStart(Marker m) async {}
}

Answer<Future<void>> ignore() {
  return (_) async {};
}
