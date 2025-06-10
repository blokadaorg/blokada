import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flutter/material.dart';

class PauseDialog extends StatefulWidget {
  final Function(Duration?) onSelected;

  const PauseDialog({Key? key, required this.onSelected}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PauseDialogState();
}

class PauseDialogState extends State<PauseDialog> with Disposables {
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 32),
      _buildPauseOption(
          "home power action pause".i18n, const Duration(seconds: 60)),
      _buildPauseOption("home power action turn off".i18n, null),
    ]);
  }

  Widget _buildPauseOption(String label, Duration? duration) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CommonClickable(
          onTap: () {
            widget.onSelected.call(duration);
            Navigator.of(context).pop();
          },
          bgColor: (duration == null)
              ? context.theme.accent.withOpacity(0.3)
              : context.theme.shadow,
          tapBgColor: context.theme.divider.withOpacity(0.1),
          child: SizedBox(
            width: 180,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          )),
    );
  }
}
