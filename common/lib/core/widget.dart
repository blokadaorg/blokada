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

extension StringExt on String {
  String orIfBlank(String fallback) {
    return isBlank ? fallback : this;
  }

  String upTo(int length) {
    return length >= this.length ? this : '${substring(0, length)}…';
  }
}

String middleEllipsis(String text, {int maxLength = 24}) {
  if (text.length <= maxLength) {
    return text;
  }

  // Reserve 3 characters for the ellipsis
  if (maxLength < 6) {
    return text.substring(0, maxLength);
  }

  int charsPerSide = (maxLength - 3) ~/ 2;
  int endIndex = text.length - charsPerSide;

  return '${text.substring(0, charsPerSide)}...${text.substring(endIndex)}';
}
