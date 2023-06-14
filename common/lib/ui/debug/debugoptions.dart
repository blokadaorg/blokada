import 'package:common/util/trace.dart';
import 'package:flutter/material.dart';

import '../../tracer/tracer.dart';
import '../../util/config.dart';

class DebugOptions extends StatefulWidget {
  @override
  _DebugOptionsState createState() => _DebugOptionsState();
}

class _DebugOptionsState extends State<DebugOptions> {
  List<int> loggingOptions = [15, 60, 180]; // in minutes
  int loggingSelectedIndex = 0;

  Color _iconColor = Colors.grey;

  late TextEditingController _controller;

  void toggleLogging() {
    final isLoggingActive = _isLoggingActive();
    bool enable = !isLoggingActive && runtimeLastError == null;
    // Cycle through time options
    if (isLoggingActive && runtimeLastError == null) {
      if (loggingSelectedIndex < loggingOptions.length - 1) {
        loggingSelectedIndex++;
        enable = true;
      } else {
        loggingSelectedIndex = 0;
      }
    }

    if (enable) {
      final minutes = loggingOptions[loggingSelectedIndex];
      DateTime endDateTime = DateTime.now().add(Duration(minutes: minutes));
      cfg.debugSendTracesUntil = endDateTime;
      setState(() {});
    } else {
      runtimeLastError = null;
      cfg.debugSendTracesUntil = null;
      setState(() {});
    }
    _setIconColor();
  }

  String getLoggingStatus() {
    final date = cfg.debugSendTracesUntil;
    if (date != null && date.isAfter(DateTime.now())) {
      if (runtimeLastError != null) {
        return "Error: ${shortString(runtimeLastError!)}";
      }
      return "Active for ${date.difference(DateTime.now()).inMinutes + 1} minutes";
    } else {
      return "Logging Disabled";
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Troubleshooting'),
      content: _dialogContent(context),
      actions: <Widget>[
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
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text('Step 1', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const Text('Enable logging to allow us to diagnose your issue.',
            style: TextStyle(fontSize: 14)),
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: OutlinedButton(
            onPressed: () => toggleLogging(),
            child: Row(children: <Widget>[
              Icon(Icons.circle, color: _iconColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  getLoggingStatus(),
                  style: TextStyle(fontSize: 12, color: _iconColor),
                ),
              ),
            ]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 24.0, bottom: 8),
          child: Text('Step 2', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const Text(
            "Please recreate the issue you're experiencing. Logs are automatically and securely transmitted to us, with all data being fully encrypted. Rest assured, no sensitive information is ever incorporated within the transmitted logs.",
            style: TextStyle(fontSize: 14)),
        const Padding(
          padding: EdgeInsets.only(top: 24.0, bottom: 8.0),
          child: Text('Step 3', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const Text(
            'When you reach out to us, please include this ID. It will enable us to review and analyze your log data.',
            style: TextStyle(fontSize: 14)),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TextField(
            readOnly: true,
            controller: _controller,
            style: const TextStyle(fontSize: 12),
            onTap: () {
              _controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _controller.text.length,
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isLoggingActive() {
    return cfg.debugSendTracesUntil?.isAfter(DateTime.now()) ?? false;
  }

  _setIconColor() {
    _iconColor = _isLoggingActive()
        ? (runtimeLastError == null ? Colors.green : Colors.red)
        : Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: runtimeTraceId);
    _setIconColor();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
