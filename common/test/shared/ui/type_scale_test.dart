import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scale = BlokadaTypeScale();
  final roles = {
    'largeTitle': scale.largeTitle,
    'display': scale.display,
    'title': scale.title,
    'barAction': scale.barAction,
    'body': scale.body,
    'callout': scale.callout,
    'footnote': scale.footnote,
    'caption': scale.caption,
  };

  test('the scale keeps the sizes the screens used inline', () {
    expect(roles.map((name, style) => MapEntry(name, style.fontSize)), {
      'largeTitle': 34,
      'display': 34,
      'title': 20,
      'barAction': 17,
      'body': 16,
      'callout': 14,
      'footnote': 13,
      'caption': 12,
    });
  });

  // Swapping an inline style for a role must not move text, so a role may
  // only set size and weight and must inherit the rest.
  test('roles set only size and weight', () {
    for (final MapEntry(key: name, value: style) in roles.entries) {
      final bare = TextStyle(fontSize: style.fontSize, fontWeight: style.fontWeight);
      expect(style, bare, reason: name);
    }
  });

  testWidgets('the theme is still found by its own type', (tester) async {
    late BlokadaTheme found;
    const theme = BlokadaTheme(
      bgColor: Colors.white,
      bgColorHome1: Colors.white,
      bgColorHome2: Colors.white,
      bgColorHome3: Colors.white,
      bgColorCard: Colors.white,
      panelBackground: Colors.white,
      cloud: Colors.blue,
      accent: Colors.orange,
      freemium: Colors.teal,
      shadow: Colors.grey,
      bgMiniCard: Colors.white,
      textPrimary: Colors.black,
      textSecondary: Colors.black54,
      divider: Colors.black26,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [theme]),
        home: Builder(
          builder: (context) {
            found = context.theme;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found.text.body.fontSize, 16);
  });
}
