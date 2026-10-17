# Golden tests

Screenshot tests for the v6 screens: Home (inactive, active), Privacy Pulse,
Activity, Advanced and Settings. Each test boots the app's real modules in the
`test` scenario (no platform channels), seeds the stores with fixed data
(`fixtures.dart`), serves API calls from canned JSON (`fake_http.dart`),
renders the real shell at the size of a 1080×2400 Android phone, in dark mode
and again in light mode (`<name>_light.png`), and compares the frame with a PNG
in `goldens/`.

```bash
cd common
fvm flutter test test/golden/                    # compare against goldens/
fvm flutter test test/golden/ --update-goldens   # regenerate after an intended UI change
```

Review regenerated PNGs in the PR diff like any other change.

- Goldens are generated on Linux. Text and anti-aliasing differ slightly on
  macOS, so the group is skipped elsewhere; regenerate them on Linux (a cloud
  session or any Linux machine). CI runs them in the `Flutter test` job and,
  on a mismatch, uploads the master, test and diff images as the
  `golden-failures-*` artifact.
- Real fonts are loaded in `golden_tools.dart`: Roboto and Material icons from
  the Flutter SDK, Cupertino icons from the version in `pubspec.lock`. Without
  them tests draw text with a placeholder font.
- Fixture dates are far in the future and fake API timestamps are relative to
  now, so the images do not change with the calendar.
- To add a screen: seed what it reads in `fixtures.dart`, add any endpoints it
  fetches to `fake_http.dart` (unknown paths throw, naming the path), then call
  `expectScreen(tester, 'name', path: Paths.x)`.
