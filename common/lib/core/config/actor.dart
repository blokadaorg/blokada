part of '../core.dart';

mixin Actor {
  late final Act act;

  bool _registered = false;
  bool _started = false;

  void register(Act act) {
    if (_registered) throw Exception("Actor already registered");
    _registered = true;

    this.act = act;
    onRegister(act);
  }

  Future<void> start(Marker m) async {
    if (_started) throw Exception("Actor already started");
    _started = true;

    await onStart(m);
  }

  void onRegister(Act act) {}
  Future<void> onStart(Marker m) async {}
}

Answer<Future<void>> ignore() {
  return (_) async {};
}
