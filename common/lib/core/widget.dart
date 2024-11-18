part of 'core.dart';

mixin Disposables<T extends StatefulWidget> on State<T> {
  var _subscriptions = <StreamSubscription>[];
  var _animationControllers = <AnimationController>[];

  rebuild(dynamic it) {
    if (!mounted) return;
    setState(() {});
  }

  disposeLater(dynamic it) {
    if (it is StreamSubscription) {
      _subscriptions.add(it);
    } else if (it is AnimationController) {
      _animationControllers.add(it);
    }
  }

  disposeAll() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions = [];

    for (final ctrl in _animationControllers) {
      ctrl.dispose();
    }

    _animationControllers = [];
  }
}
