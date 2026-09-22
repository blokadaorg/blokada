import 'package:common/src/app_variants/v6/module/attach/attach.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Offers the two ways to hand this account over to another device: open the
/// link right here (when the other device is this one's browser) or share it
/// (when it is a laptop across the room).
///
/// Each tap mints its own token, so the sheet stays usable for a second device
/// after the first one worked, and it only closes once a tap succeeded.
class AttachSheet extends StatefulWidget {
  const AttachSheet({super.key});

  @override
  State<StatefulWidget> createState() => AttachSheetState();
}

class AttachSheetState extends State<AttachSheet> with Logging {
  late final _attach = Core.get<AttachActor>();

  bool _working = false;

  Future<void> _open() => _run("attachOpen", (m) => _attach.openInBrowser(m));

  Future<void> _share() => _run("attachShare", (m) => _attach.share(m));

  /// Both actions differ only in what they do with the link, and both can fail
  /// the same way (offline, or an account that lapsed while this sheet was
  /// open), so the busy state and the error dialog live here.
  Future<void> _run(String name, Future<void> Function(Marker m) action) async {
    if (_working) return;
    setState(() => _working = true);

    try {
      await log(Markers.userTap).trace(name, (m) async => await action(m));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      showErrorDialog(context, _describeError(e));
    }
  }

  String _describeError(Object e) {
    if (e is HttpCodeException && e.code == 403) {
      return "error account inactive generic".i18n;
    }
    return "attach error generic".i18n;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColorCard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Text(
                "attach sheet header".i18n,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium!
                    .copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  "attach sheet brief".i18n,
                  softWrap: true,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: context.theme.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Icon(
                  CupertinoIcons.device_laptop,
                  color: context.theme.bgColorHome2,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              _button(
                identifier: AutomationIds.attachOpen,
                text: "attach action open".i18n,
                icon: CupertinoIcons.compass,
                color: context.theme.accent,
                textColor: Colors.white,
                onTap: _open,
              ),
              const SizedBox(height: 8),
              _button(
                identifier: AutomationIds.attachShare,
                text: "attach action share".i18n,
                icon: CupertinoIcons.share,
                color: context.theme.bgColor,
                textColor: context.theme.textPrimary,
                onTap: _share,
              ),
              const SizedBox(height: 12),
              // Android has no obvious "swipe the sheet away" affordance, so
              // give the user an explicit way out. Not while a link is being
              // minted, though: the tap would still open the browser or the
              // share sheet seconds after this one is gone.
              CommonClickable(
                onTap: _working ? null : () => Navigator.of(context).pop(),
                child: Text("universal action cancel".i18n,
                    style: TextStyle(
                        color: _working
                            ? context.theme.textSecondary
                            : context.theme.accent)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button({
    required String identifier,
    required String text,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Semantics(
              identifier: identifier,
              button: true,
              child: MiniCard(
                onTap: _working ? null : onTap,
                color: color,
                child: SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _working
                          ? const CupertinoActivityIndicator()
                          : Icon(icon, color: textColor),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
