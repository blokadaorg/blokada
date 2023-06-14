import 'package:flutter/material.dart';

import '../../entrypoint.dart';
import '../../util/async.dart';
import '../../util/di.dart';
import '../../util/trace.dart';

class CommandDialog extends StatefulWidget {
  const CommandDialog({super.key});

  @override
  CommandDialogState createState() => CommandDialogState();
}

class CommandDialogState extends State<CommandDialog> with TraceOrigin {
  late final _entrypoint = dep<Entrypoint>();

  late TextEditingController _controllerCmd;
  late TextEditingController _controllerOutput;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Command'),
      content: _dialogContent(context),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          child: const Text('Execute'),
          onPressed: () {
            _executeCommand();
          },
        ),
        TextButton(
          style: TextButton.styleFrom(
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          child: const Text('Close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _dialogContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Enter the command to execute.',
            style: TextStyle(fontSize: 14)),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TextField(
            readOnly: false,
            autocorrect: false,
            controller: _controllerCmd,
            style: const TextStyle(fontSize: 12),
            onTap: () {},
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 24.0, bottom: 8),
          child: Text('Output', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TextField(
            readOnly: true,
            controller: _controllerOutput,
            style: const TextStyle(fontSize: 12),
            minLines: 5,
            maxLines: 10,
            onTap: () {
              _controllerOutput.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controllerOutput.text.length,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _controllerCmd = TextEditingController(text: "");
    _controllerOutput = TextEditingController(text: "");
  }

  @override
  void dispose() {
    _controllerCmd.dispose();
    _controllerOutput.dispose();
    super.dispose();
  }

  _executeCommand() async {
    final command = _controllerCmd.text;
    if (command.isNotEmpty) {
      await traceAs("commandDialog", (trace) async {
        try {
          _controllerOutput.text = "...";
          if (command.contains("&&")) {
            // Split and trim
            final cmds = command.split("&&").map((cmd) => cmd.trim()).toList();
            for (final cmd in cmds) {
              if (cmd.isEmpty) continue;
              if (cmds.length > 1) {
                await sleepAsync(const Duration(milliseconds: 500));
              }
              try {
                await _entrypoint.onCommandString(trace, cmd);
                _controllerOutput.text += "\nOK: $cmd";
              } catch (e) {
                _controllerOutput.text += "\nFail: $cmd: $e";
              }
            }
            return;
          } else {
            await _entrypoint.onCommandString(trace, command);
          }
          _controllerOutput.text = "OK";
        } catch (e) {
          _controllerOutput.text = "Fail: $e";
        }
      });
    } else {
      _controllerOutput.text = "Fail: no command";
    }
  }
}
