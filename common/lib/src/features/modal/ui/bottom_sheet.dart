import 'dart:io';

import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

const maxSheetWidth = 600.0;

// Simply displays one of our predefined bottom sheets based on the Value that
// can be modified by other parts of the app. Ensures widget context is provided.
// Please note that old StageStore handling of modal is not integrated with this
// newer approach yet. It should be eventually.
//
// This class expects actual modal widgets to be registered in DI for type
// Widget and tag being enum Modal.name.
class BottomManagerSheet extends StatefulWidget {
  const BottomManagerSheet({super.key});

  @override
  State<StatefulWidget> createState() => BottomManagerSheetState();
}

class BottomManagerSheetState extends State<BottomManagerSheet>
    with WidgetsBindingObserver, Disposables, Logging {
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  @override
  void initState() {
    super.initState();
    //WidgetsBinding.instance.addObserver(this);
    disposeLater(_modalWidget.onChange.listen(rebuild));
  }

  @override
  void dispose() {
    //WidgetsBinding.instance.removeObserver(this);
    disposeAll();
    super.dispose();
  }

  @override
  rebuild(it) {
    if (!mounted) return;
    final widget = _modalWidget.present;
    if (widget == null) return;
    _show(widget);
  }

  _show(WidgetBuilder widget) {
    try {
      _showSheet(context, builder: widget);
    } catch (e, s) {
      log(Markers.ui).e(msg: "Failed showing modal widget", err: e, stack: s);
    }
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);
  //   if (state == AppLifecycleState.resumed) {
  //     _show(); // TODO: needed?
  //   }
  // }

  @override
  Widget build(BuildContext context) => Container();
}

_showSheet(BuildContext context, {required WidgetBuilder builder}) async {
  final screenWidth = MediaQuery.of(context).size.width;

  if (screenWidth > maxSheetWidth) {
    return showCustomModalBottomSheet(
      context: context,
      duration: const Duration(milliseconds: 300),
      backgroundColor: context.theme.bgColorCard,
      builder: builder,
      containerWidget: (_, animation, child) => FloatingModal(child: child),
      expand: false,
    );
  }

  return showCupertinoModalBottomSheet(
    context: context,
    duration: const Duration(milliseconds: 300),
    backgroundColor:
        Platform.isAndroid ? Colors.transparent : context.theme.bgColorCard,
    builder: (c) => Padding(
        padding: EdgeInsets.only(top: Platform.isAndroid ? 24 : 0),
        child: builder(c)),
  );
}

class FloatingModal extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const FloatingModal({super.key, required this.child, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final factor = maxSheetWidth / screenWidth;

    return Center(
      child: FractionallySizedBox(
        widthFactor: factor,
        heightFactor: 0.9,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: backgroundColor,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
