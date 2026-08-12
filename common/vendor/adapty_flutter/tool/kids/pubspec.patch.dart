import 'dart:io';

// Usage: dart tool/kids/pubspec.patch.dart <path-to-pubspec.yaml>
// Rewrites the top-level `name:` to adapty_flutter_kids and `description:` to the kids variant,
// leaving everything else (version, environment, dependencies, flutter.plugin) untouched.
void main(List<String> args) {
  final file = File(args.single);
  final lines = file.readAsLinesSync();
  final out = <String>[];
  for (final line in lines) {
    if (line.startsWith('name:')) {
      out.add('name: adapty_flutter_kids');
    } else if (line.startsWith('description:')) {
      out.add(
          'description: Kids Mode (COPPA / App Store Kids Category) variant of adapty_flutter. '
          'iOS compiles out IDFA / AdSupport via the AdaptySDK-iOS KidsMode trait; same public API.');
    } else {
      out.add(line);
    }
  }
  stdout.write('${out.join('\n')}\n');
}
