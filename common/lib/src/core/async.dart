part of 'core.dart';

Future<void> sleepAsync(Duration duration) async {
  await Future.delayed(duration);
}

class Debounce {
  final Duration duration;
  Timer? _timer;

  Debounce(this.duration);

  void run(Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
