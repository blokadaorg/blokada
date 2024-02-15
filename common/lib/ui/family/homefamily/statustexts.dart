import 'package:common/service/I18nService.dart';
import 'package:flutter/material.dart';

import '../../../common/model.dart';
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
          "family status fresh header".i18n,
          "${"family status fresh body".i18n}\n\n",
        ];
      case FamilyPhase.parentNoDevices:
        return [
          "family status ready header".i18n,
          "${"family status ready body".i18n}\n\n",
        ];
      case FamilyPhase.linkedActive || FamilyPhase.linkedUnlocked:
        return [
          "family status linked header".i18n,
        ];
      case FamilyPhase.linkedNoPerms ||
            FamilyPhase.lockedNoPerms ||
            FamilyPhase.noPerms:
        return [
          "family status perms header".i18n,
          "${"family status perms body".i18n}\n\n",
        ];
      case FamilyPhase.lockedNoAccount:
        return [
          "family status expired header".i18n,
          "${"family status expired body".i18n}\n\n",
        ];
      case FamilyPhase.lockedActive:
        return [
          "family status locked header".i18n,
        ];
      default:
        return [""];
    }
  }
}
