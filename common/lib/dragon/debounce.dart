import 'dart:async';

class Debounce {
  final Duration duration;
  Timer? _timer;

  Debounce(this.duration);

  void run(Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }
}
