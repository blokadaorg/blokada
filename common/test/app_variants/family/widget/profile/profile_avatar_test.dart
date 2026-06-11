import 'package:common/src/app_variants/family/widget/profile/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paletteColor is deterministic per alias', () {
    final c1 = ProfileAvatar.paletteColor('Homework');
    final c2 = ProfileAvatar.paletteColor('Homework');
    expect(c1, c2);
  });

  test('paletteColor differs across distinct aliases', () {
    // Not a hard guarantee for ALL aliases (palette is 6 colors so
    // collisions are possible), but two specific aliases shouldn't both
    // land on _palette.first (orange). At least one should differ from
    // the empty-alias fallback.
    final empty = ProfileAvatar.paletteColor('');
    final school = ProfileAvatar.paletteColor('School');
    final bedtime = ProfileAvatar.paletteColor('Bedtime');
    // At least one of these isn't the empty-alias fallback color.
    expect(
        school != empty || bedtime != empty,
        isTrue,
        reason:
            'Hash distribution should make at least one of School/Bedtime miss the empty-alias slot.');
  });

  testWidgets('Custom template renders the first letter uppercased',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProfileAvatar(
          template: '',
          displayAlias: 'homework',
          size: 24,
        ),
      ),
    ));
    expect(find.text('H'), findsOneWidget);
  });

  testWidgets('Empty alias falls back to question mark', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProfileAvatar(
          template: '',
          displayAlias: '',
          size: 24,
        ),
      ),
    ));
    expect(find.text('?'), findsOneWidget);
  });
}
