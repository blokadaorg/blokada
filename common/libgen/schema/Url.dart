import 'package:pigeon/pigeon.dart';

// A bit of a special binding, we try to not use url_launcher
// flutter plugin, as we are having problems with Apple
// rejecting it (some signing problem).
// Instead we just want to fulfill the expected interface.
// Used by the chat ui dependency.

// This pigeon taken from:
// https://chromium.googlesource.com/external/github.com/flutter/packages/+/refs/tags/url_launcher_ios-v6.3.1/packages/url_launcher/url_launcher_ios/pigeons/messages.dart?autodive=0%2F

/// Possible outcomes of launching a URL.
enum LaunchResult {
  /// The URL was successfully launched (or could be, for `canLaunchUrl`).
  success,

  /// There was no handler available for the URL.
  failure,

  /// The URL could not be launched because it is invalid.
  invalidUrl,
}

/// Possible outcomes of handling a URL within the application.
enum InAppLoadResult {
  /// The URL was successfully loaded.
  success,

  /// The URL did not load successfully.
  failedToLoad,

  /// The URL could not be launched because it is invalid.
  invalidUrl,
}

@HostApi()
abstract class UrlLauncherApi {
  /// Checks whether a URL can be loaded.
  @ObjCSelector('canLaunchURL:')
  LaunchResult canLaunchUrl(String url);

  /// Opens the URL externally, returning the status of launching it.
  @async
  @ObjCSelector('launchURL:universalLinksOnly:')
  LaunchResult launchUrl(String url, bool universalLinksOnly);

  /// Opens the URL in an in-app SFSafariViewController, returning the results
  /// of loading it.
  @async
  @ObjCSelector('openSafariViewControllerWithURL:')
  InAppLoadResult openUrlInSafariViewController(String url);

  /// Closes the view controller opened by [openUrlInSafariViewController].
  void closeSafariViewController();
}
