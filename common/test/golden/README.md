# Golden tests

Screenshot tests for the v6 screens. Each test boots the app's real modules in
the `test` scenario (no platform channels, no backend), seeds the stores with
fixed data (`fixtures.dart`), renders the real shell at the size of a 1080×2400
Android phone in dark mode, and compares the frame with a PNG in `goldens/`.

```bash
cd common
fvm flutter test test/golden/                    # compare against goldens/
fvm flutter test test/golden/ --update-goldens   # regenerate after an intended UI change
```

Review regenerated PNGs in the PR diff like any other change.

- Goldens are generated on Linux. Text and anti-aliasing differ slightly on
  macOS, so regenerate them on Linux (CI or a cloud session), not on a Mac.
- Real fonts are loaded in `golden_tools.dart`: Roboto and Material icons from
  the Flutter SDK, Cupertino icons from the pub cache. Without them tests draw
  text with a placeholder font.
- To add a screen: seed what it reads in `fixtures.dart`, then call
  `expectScreen(tester, 'name', path: Paths.x)`.
- Privacy Pulse loads its counters, top domains and activity from the API, so
  its golden shows the loading state until those fetches are faked.
