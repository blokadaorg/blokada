import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Visual identity for a profile chip / row. Pinned templates (`parent`,
/// `child`) keep their dedicated person icons + colors so the at-a-glance
/// "who is this" stays. Every other template renders as a colored circle
/// with the alias's first letter — colored deterministically from a content
/// hash of the alias over a curated 6-color palette that avoids the pinned
/// blue (parent) and green (child) so the two categories stay visually
/// distinct.
class ProfileAvatar extends StatelessWidget {
  final String template;
  final String displayAlias;
  final double size;

  const ProfileAvatar({
    Key? key,
    required this.template,
    required this.displayAlias,
    this.size = 18,
  }) : super(key: key);

  static const List<Color> _palette = [
    Color(0xFFFF9500), // orange
    Color(0xFFAF52DE), // purple
    Color(0xFF5AC8FA), // teal-cyan
    Color(0xFFFF2D55), // pink
    Color(0xFF5856D6), // indigo
    Color(0xFFFFCC00), // yellow
  ];

  static Color paletteColor(String alias) {
    if (alias.isEmpty) return _palette.first;
    // Dart's `String.hashCode` is not guaranteed stable across process runs,
    // so using it would flip a profile's avatar color between app launches.
    // Fold the code units with a small deterministic hash instead so the
    // same alias always maps to the same palette slot.
    var h = 0;
    for (final unit in alias.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    switch (template) {
      case 'parent':
        return Icon(CupertinoIcons.person_2_alt,
            size: size, color: Colors.blue);
      case 'child':
        return Icon(Icons.child_care, size: size, color: Colors.green);
      default:
        final color = paletteColor(displayAlias);
        // Grapheme-cluster first character so a leading emoji (which
        // occupies a UTF-16 surrogate pair) renders as the emoji itself
        // rather than the unpaired high surrogate, which falls back to
        // the missing-glyph box / "?".
        final graphemes = displayAlias.characters;
        final glyph = graphemes.isEmpty
            ? '?'
            : graphemes.first.toUpperCase();
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            glyph,
            style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w700),
          ),
        );
    }
  }
}
