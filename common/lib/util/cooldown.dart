mixin Cooldown {
  DateTime _timestamp = DateTime(0);

  bool isCooledDown(Duration duration) {
    final ready = DateTime.now().difference(_timestamp) > duration;
    if (ready) {
      _timestamp = DateTime.now();
    }
    return ready;
  }
}
