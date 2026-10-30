import 'package:common/src/core/core.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// A quiet link under the main button of a screen where people get stuck,
/// which opens the support chat sheet over what is under that screen.
///
/// Grey, never the accent color, so it does not compete with the main
/// button. It reads "Continue with support" while a chat is open, since
/// that chat is what the sheet then shows.
class AskSupportLink extends StatefulWidget {
  /// Opens a new chat, telling the agent where the user asked for help.
  final SupportEvent event;

  /// Closes the screen the link is on, before the chat sheet opens.
  final Future<void> Function(Marker m) close;

  const AskSupportLink({super.key, required this.event, required this.close});

  @override
  State<StatefulWidget> createState() => AskSupportLinkState();
}

class AskSupportLinkState extends State<AskSupportLink> with Logging {
  late final _support = Core.get<SupportActor>();

  bool? _sessionOpen;

  @override
  void initState() {
    super.initState();
    _support.isSessionOpen(Markers.ui).catchError((e, s) {
      log(Markers.ui).e(msg: "Error reading support session", err: e, stack: s);
      return false;
    }).then((open) {
      if (mounted) setState(() => _sessionOpen = open);
    });
  }

  void _tap() {
    // Read before closing, which takes this link off screen.
    final support = _support;
    final event = widget.event;
    final close = widget.close;
    log(Markers.userTap).trace("askSupport", (m) async {
      await close(m);
      await support.askSupport(m, event);
    });
  }

  @override
  Widget build(BuildContext context) {
    final open = _sessionOpen;
    final label = open == true ? "support action continue".i18n : "support action ask".i18n;
    // The label stays hidden until the stored session is read, so it never
    // switches while the user looks at it. The space is kept meanwhile.
    return Semantics(
      identifier: AutomationIds.askSupport,
      button: open != null,
      child: TextButton(
        onPressed: open == null ? null : _tap,
        style: TextButton.styleFrom(
          foregroundColor: context.theme.textSecondary,
          disabledForegroundColor: Colors.transparent,
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
