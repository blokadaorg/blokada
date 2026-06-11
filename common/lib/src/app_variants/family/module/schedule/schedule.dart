import 'package:common/src/core/core.dart';

part 'json.dart';
part 'seed_templates.dart';
part 'summary.dart';
part 'active_profile.dart';

/// Schedule module surface.
///
/// A Schedule lives on each Family device's config record alongside the
/// existing `profile_id` (which continues to serve as the device's Default).
/// The Schedule itself carries only the override rules and a `paused` flag —
/// the resolver evaluates rules per DNS query in the device's local clock and
/// falls back to `profile_id` when no rule matches or `paused == true`.
///
/// This library owns the Dart mirror of the wire format and the pure helpers
/// (summary strings, preset translation, seeded templates). The mutating
/// actor lives next door in `actor.dart` to avoid a circular import with
/// the device-v3 module.
