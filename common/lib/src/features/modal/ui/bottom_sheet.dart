import 'dart:io';

import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

const maxSheetWidth = 500.0;

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
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  // Tracks whether a sheet is currently displayed by us. Prevents pushing
  // duplicate sheets when [_modalWidget] re-emits (e.g. when the same modal
  // type is requested multiple times during cold start while the previous
  // sheet is still on screen).
  bool _isShowing = false;

  // Captured at sheet show time so we can pop *that* sheet on programmatic
  // dismiss without accidentally popping an unrelated route that happened to
  // become topmost in the meantime.
  NavigatorState? _activeSheetNavigator;

  @override
  void initState() {
    super.initState();
    //WidgetsBinding.instance.addObserver(this);
    disposeLater(_modalWidget.onChange.listen(rebuild));
    // Also listen to the modal value itself so we can pop the active sheet
    // when callers signal "no modal should be shown" by setting it to null
    // (e.g. DNS wizard auto-dismiss when cloudPermEnabled flips true).
    disposeLater(_modal.onChange.listen(_onModalChanged));
    WidgetsBinding.instance.addPostFrameCallback((_) => rebuild(null));
  }

  void _onModalChanged(it) {
    if (!mounted) return;
    if (it.now == null && _isShowing) {
      // The active sheet's _show future will resolve in its finally block,
      // which clears _isShowing and the modal value (already null). Pop the
      // navigator we captured at show time, not Navigator.of(context), so we
      // don't accidentally pop some unrelated route on top of the same root.
      _activeSheetNavigator?.maybePop();
    }
  }

  @override
  void dispose() {
    //WidgetsBinding.instance.removeObserver(this);
    // Clear the modal value so a remount of this widget (e.g. theme change)
    // does not see a stale value and re-show a sheet that is no longer alive.
    _modal.change(Markers.ui, null);
    disposeAll();
    super.dispose();
  }

  @override
  rebuild(it) {
    if (!mounted) return;
    if (_isShowing) return;
    final widget = _modalWidget.present;
    if (widget == null) return;
    _show(widget);
  }

  Future<void> _show(WidgetBuilder widget) async {
    _isShowing = true;
    _activeSheetNavigator = Navigator.of(context, rootNavigator: true);
    try {
      await _showSheet(context, builder: widget);
    } catch (e, s) {
      log(Markers.ui).e(msg: "Failed showing modal widget", err: e, stack: s);
    } finally {
      _isShowing = false;
      _activeSheetNavigator = null;
      // Sheet has been dismissed (by the user, by Navigator.pop, or by our
      // _onModalChanged listener). Clear the modal value so the next request
      // to show the same modal type is not deduped by the NullableAsyncValue
      // equality check.
      if (mounted) {
        await _modal.change(Markers.ui, null);
      }
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

Future<void> _showSheet(BuildContext context, {required WidgetBuilder builder}) async {
  final screenWidth = MediaQuery.of(context).size.width;

  if (screenWidth >= maxSheetWidth) {
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
