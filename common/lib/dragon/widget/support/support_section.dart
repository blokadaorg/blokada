import 'package:common/common/i18n.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/support/controller.dart';
import 'package:common/dragon/widget/navigation.dart';
import 'package:common/dragon/widget/support/convert.dart';
import 'package:common/logger/logger.dart';
import 'package:common/util/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

class SupportSection extends StatefulWidget {
  const SupportSection({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SupportSectionState();
}

class SupportSectionState extends State<SupportSection> {
  late final _controller = dep<SupportController>();

  final List<types.Message> _messages = [];

  final _me = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final _notMe = const types.User(
    id: 'f590b0b3-3b6b-4b7b-8b3b-3b6b4b7b8b3b',
    firstName: "Blocka Bot",
    //imageUrl: "assets/images/appicon.png",
  );

  @override
  void initState() {
    super.initState();
    _controller.onChange = _refresh;
    _controller.loadOrInit(Markers.support);
    _refresh();
  }

  _refresh() {
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _messages
          .addAll(_controller.messages.map((e) => e.toMessage(_me, _notMe)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16.0, right: 16.0, top: getTopPadding(context), bottom: 32.0),
      child: Chat(
        messages: _messages.reversed.toList(),
        onSendPressed: _handleSendPressed,
        user: _me,
        theme: context.theme.chatTheme,
        showUserAvatars: true,
        showUserNames: true,
        inputOptions: const InputOptions(
          sendButtonVisibilityMode: SendButtonVisibilityMode.always,
        ),
        emptyState: Center(child: Text("support placeholder".i18n)),
      ),
    );
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _handleSendPressed(types.PartialText message) {
    _controller.sendMessage(message.text, Markers.support);
  }
}
