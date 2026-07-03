import 'package:flutter/widgets.dart';

/// Window size classification for adaptive layout.
///
/// Exists so layout decisions (single column vs master-detail, sheet style)
/// come from one reactive, unit-testable rule instead of scattered
/// MediaQuery width checks and the startup-cached `Navigation.isTabletMode`
/// static, which went stale on iPad Split View / Slide Over and macOS
/// window resizing.
enum WindowShape {
  /// Phone-sized: single column, bottom-anchored sheets.
  compact,

  /// Wide enough for floating sheets and roomier content, but not for a
  /// master-detail split (e.g. iPad portrait, landscape phones).
  medium,

  /// Wide and tall enough for a two-pane master-detail layout.
  expanded,
}

/// Windows at least this wide are [WindowShape.medium] (Material 3 medium
/// window class boundary).
const double kMediumWindowMinWidth = 600.0;

/// Transitional [WindowShape.expanded] threshold, matching the legacy
/// `isTabletMode` rule (strictly wider than 1000) so migrating screens
/// render identically. The breakpoint-flip stage replaces this with the
/// Material 3 expanded class (width >= 840) plus a height guard, so
/// landscape phones and squat windows stay out of two-pane layouts.
const double kLegacyExpandedMinWidth = 1000.0;

/// Classifies a window size. Pure so breakpoint behavior is unit-testable;
/// widget code should normally use [windowShapeOf].
WindowShape windowShapeFor(Size size) {
  if (size.width > kLegacyExpandedMinWidth) return WindowShape.expanded;
  if (size.width >= kMediumWindowMinWidth) return WindowShape.medium;
  return WindowShape.compact;
}

/// Classifies the current window per build. Uses `MediaQuery.sizeOf` so the
/// caller rebuilds (and re-layouts) whenever the window is resized or
/// rotated — the property the old cached static lacked.
WindowShape windowShapeOf(BuildContext context) {
  return windowShapeFor(MediaQuery.sizeOf(context));
}
