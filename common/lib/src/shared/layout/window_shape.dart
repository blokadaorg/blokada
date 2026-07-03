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

/// Minimum width for [WindowShape.expanded] (Material 3 expanded window
/// class boundary). Notably includes iPad 2/3 Split View (~980pt) and 11"
/// iPad landscape splits, which the old `> 1000` rule wasted as a
/// stretched single column.
const double kExpandedWindowMinWidth = 840.0;

/// Height guard for [WindowShape.expanded]: landscape phones (932x430)
/// and squat macOS windows are wide but cannot fit the 100pt top bar plus
/// a useful master-detail, so they stay [WindowShape.medium]. A plain
/// shortestSide rule was rejected because a short-but-wide macOS window
/// (e.g. 1200x500) does fit two panes.
const double kExpandedWindowMinHeight = 500.0;

/// Windows at least this wide present modal sheets as centered floating
/// cards instead of bottom-anchored sheets (see FloatingModal). Narrower
/// than the expanded boundary on purpose: 500-840pt windows keep a
/// single-pane layout but already look wrong with a full-width bottom
/// sheet.
const double minWidthFloatingSheet = 500.0;

/// Classifies a window size. Pure so breakpoint behavior is unit-testable;
/// widget code should normally use [windowShapeOf].
WindowShape windowShapeFor(Size size) {
  if (size.width >= kExpandedWindowMinWidth && size.height >= kExpandedWindowMinHeight) {
    return WindowShape.expanded;
  }
  if (size.width >= kMediumWindowMinWidth) return WindowShape.medium;
  return WindowShape.compact;
}

/// Classifies the current window per build. Uses `MediaQuery.sizeOf` so the
/// caller rebuilds (and re-layouts) whenever the window is resized or
/// rotated — the property the old cached static lacked.
WindowShape windowShapeOf(BuildContext context) {
  return windowShapeFor(MediaQuery.sizeOf(context));
}
