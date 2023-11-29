import 'package:flutter/material.dart';

import '../../../family/model.dart';
import '../../../util/trace.dart';
import '../../theme.dart';

class StatusTexts extends StatefulWidget {
  final FamilyPhase phase;

  const StatusTexts({super.key, required this.phase});

  @override
  State<StatefulWidget> createState() => StatusTextsState();
}

class StatusTextsState extends State<StatusTexts>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    final texts = _getTexts(widget.phase);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            texts.first!,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (texts.length > 1)
            Text(
              texts[1]!,
              style: TextStyle(
                fontSize: 18,
                color: theme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }

  List<String?> _getTexts(FamilyPhase phase) {
    switch (phase) {
      case FamilyPhase.fresh:
        return [
          "Hi there!",
          "Activate or restore your account to continue" + "\n\n",
        ];
      case FamilyPhase.parentNoDevices:
        return [
          "App is ready!",
          "Add your first device now" + "\n\n",
        ];
      case FamilyPhase.linkedActive || FamilyPhase.linkedUnlocked:
        return [
          "App is linked!",
        ];
      case FamilyPhase.linkedNoPerms || FamilyPhase.lockedNoPerms:
        return [
          "Almost there!",
          "Please grant the necessary permissions" + "\n\n",
        ];
      case FamilyPhase.lockedNoAccount:
        return [
          "Account expired",
          "Please activate your account to continue" + "\n\n",
        ];
      case FamilyPhase.lockedActive:
        return [
          "App is locked",
        ];
      default:
        return [""];
    }
  }
}
