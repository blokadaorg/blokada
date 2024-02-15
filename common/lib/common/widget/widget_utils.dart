part of '../widget.dart';

mixin ViaTools<T extends StatefulWidget> on State<T> {
  rebuild() => setState(() {});
}

Color genColor(String id) {
  final bytes = utf8.encode(id);
  final hash = sha256.convert(bytes);
  final hashBytes = hash.bytes;

  double red = hashBytes[0] / 255.0;
  double green = hashBytes[1] / 255.0;
  double blue = hashBytes[2] / 255.0;

  return Color.fromRGBO(
      (red * 255).round(), (green * 255).round(), (blue * 255).round(), 1);
}

extension StringExtension on String {
  String firstLetterUppercase() {
    if (isEmpty) {
      return this;
    }
    return this[0].toUpperCase() + substring(1);
  }
}

extension ThemeOnWidget on BuildContext {
  BlokadaTheme get theme => Theme.of(this).extension<BlokadaTheme>()!;
}

class StandardRoute extends MaterialWithModalsPageRoute {
  StandardRoute(
      {required WidgetBuilder builder, required RouteSettings settings})
      : super(builder: builder, settings: settings);

  late TopBarController ctrl;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  void _updateTopBar() {
    final v = secondaryAnimation?.value;
    if (v == null || v > 1.0 || v < 0.0) return;
    ctrl.updateUserGesturePos(v);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    ctrl = Provider.of<TopBarController>(context, listen: false);

    secondaryAnimation.addListener(_updateTopBar);

    // Use a builder that removes the listener when the animation widget disposes
    return AnimatedBuilder(
      animation: secondaryAnimation,
      builder: (context, c) {
        return super
            .buildTransitions(context, animation, secondaryAnimation, child);
      },
      child: child,
    );
  }

  @override
  bool didPop(dynamic result) {
    animation?.removeListener(_updateTopBar);
    return super.didPop(result);
  }
}

void showInputDialog(
  BuildContext context, {
  required String title,
  required String desc,
  required String inputValue,
  required Function(String) onConfirm,
}) {
  final TextEditingController _ctrl = TextEditingController(text: inputValue);

  showDefaultDialog(
    context,
    title: Text(title),
    content: (context) => Column(
      children: [
        Text(desc),
        const SizedBox(height: 16),
        Material(
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.theme.panelBackground,
              focusColor: context.theme.panelBackground,
              hoverColor: context.theme.panelBackground,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: context.theme.divider, width: 1.0),
                borderRadius: BorderRadius.circular(2.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: context.theme.divider, width: 1.0),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
        ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text("Cancel"),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm(_ctrl.text);
        },
        child: const Text("Save"),
      ),
    ],
  );
}

void showDefaultDialog(
  context, {
  required Text title,
  required Widget Function(BuildContext) content,
  required List<Widget> Function(BuildContext) actions,
}) {
  Platform.isIOS || Platform.isMacOS
      ? showCupertinoDialog<String>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) => CupertinoAlertDialog(
            title: title,
            content: content(context),
            actions: actions(context),
          ),
        )
      : showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) => AlertDialog(
            title: title,
            content: content(context),
            actions: actions(context),
          ),
        );
}
