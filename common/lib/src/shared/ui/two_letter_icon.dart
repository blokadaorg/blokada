import 'package:common/src/shared/ui/color.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

class TwoLetterIconWidget extends StatelessWidget {
  final String name;
  final Color? colorOverride;
  final bool big;

  const TwoLetterIconWidget(
      {super.key, required this.name, this.colorOverride, this.big = false});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final color = colorOverride ?? genColor(name, isDarkMode: isDarkMode);
    Color baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: baseColor,
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.5),
              color,
            ],
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
          ),
        ),
        child: SizedBox(
          width: big ? 60 : 32,
          height: big ? 60 : 32,
          child: Center(
            child: Text(
              name.isBlank ? name : name.substring(0, 2).toUpperCase().trim(),
              style: TextStyle(
                fontSize: big ? 24 : 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
