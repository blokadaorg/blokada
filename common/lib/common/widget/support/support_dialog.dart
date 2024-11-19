import 'package:common/common/module/support/support.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/command/command.dart';
import 'package:common/platform/link/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/cupertino.dart';

class SupportDialog extends StatefulWidget {
  const SupportDialog({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SupportDialogState();
}

class SupportDialogState extends State<SupportDialog> with Logging {
  late final _support = DI.get<SupportActor>();
  late final _command = DI.get<CommandStore>();
  late final _stage = DI.get<StageStore>();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("account support action how help".i18n),
        const SizedBox(height: 40),
        _buildButton(
          context,
          CupertinoIcons.chat_bubble_text,
          "New chat",
          onTap: () {
            _support.startSession(Markers.userTap);
          },
        ),
        _buildButton(
          context,
          CupertinoIcons.doc_text,
          "universal action share log".i18n,
          onTap: () {
            log(Markers.userTap).trace("supportSendLog", (m) async {
              await _command.onCommand("log", m);
            });
          },
        ),
        _buildButton(
          context,
          CupertinoIcons.person_2,
          "account action about".i18n,
          onTap: () {
            _stage.openLink(LinkId.credits, Markers.userTap);
          },
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context, IconData icon, String text,
      {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: CommonClickable(
        onTap: onTap,
        tapBgColor: context.theme.divider,
        //tapBorderRadius: BorderRadius.circular(24),
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: context.theme.divider.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: context.theme.accent,
                ),
                Text(
                  text,
                  style: TextStyle(
                    color: context.theme.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
