import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// Default detail-pane content when nothing is selected yet. Exists so
/// two-pane screens without a natural initial detail (Activity, Privacy
/// Pulse) show a designed empty state instead of the bare Container()
/// they used to render. Icon-only by default: proper hint copy needs a
/// new key in the translate submodule, tracked as a follow-up.
class DetailPanePlaceholder extends StatelessWidget {
  final IconData icon;
  final String? text;

  const DetailPanePlaceholder({
    super.key,
    this.icon = Icons.touch_app_outlined,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.theme.textSecondary.withOpacity(0.3);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: color),
          if (text != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                text!,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 17),
              ),
            ),
        ],
      ),
    );
  }
}
