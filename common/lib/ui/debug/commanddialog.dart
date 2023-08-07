import 'package:flutter/material.dart';

import '../../command/command.dart';
import '../../util/async.dart';
import '../../util/di.dart';
import '../../util/trace.dart';

class CommandDialog extends StatefulWidget {
  const CommandDialog({super.key});

  @override
  CommandDialogState createState() => CommandDialogState();
}

class CommandDialogState extends State<CommandDialog> with TraceOrigin {
  late final _command = dep<CommandStore>();

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
          child: const Text('Run'),
          onPressed: () async {
            _executeCommand(_controllerCmd.text);
          },
        ),
        TextButton(
          style: TextButton.styleFrom(
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          child: const Text('Run & Close'),
          onPressed: () async {
            final cmd = _controllerCmd.text;
            Navigator.of(context).pop();
            await sleepAsync(const Duration(milliseconds: 500));
            _executeCommand(cmd);
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

  _executeCommand(String command) async {
    if (command.isNotEmpty) {
      await traceAs("tappedRunCommand", (trace) async {
        try {
          if (mounted) _controllerOutput.text = "...";
          var cmds = [command];

          if (command.contains("&&")) {
            // Split and trim
            cmds = command.split("&&").map((cmd) => cmd.trim()).toList();
          }

          for (final cmd in cmds) {
            if (cmd.isEmpty) continue;
            if (cmds.length > 1) {
              await sleepAsync(const Duration(milliseconds: 500));
            }
            try {
              await _command.onCommandString(trace, cmd);
              if (mounted) _controllerOutput.text += "\nOK: $cmd";
            } catch (e) {
              // Assume that this is a shorthand for route command
              try {
                await _command.onCommandString(trace, "route $cmd");
                if (mounted) _controllerOutput.text += "\nOK: $cmd";
              } catch (e) {
                if (mounted) _controllerOutput.text += "\nFail: $cmd: $e";
              }
            }
          }
          if (mounted) _controllerOutput.text = "OK";
        } catch (e) {
          if (mounted) _controllerOutput.text = "Fail: $e";
        }
      });
    } else {
      if (mounted) _controllerOutput.text = "Fail: no command";
    }
  }
}
