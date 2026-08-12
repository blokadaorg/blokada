enum AdaptyUIIOSPresentationStyle {
  fullScreen,
  pageSheet,
}

extension AdaptyUIIOSPresentationStyleExtension on AdaptyUIIOSPresentationStyle {
  String get jsonValue => switch (this) {
        AdaptyUIIOSPresentationStyle.fullScreen => 'full_screen',
        AdaptyUIIOSPresentationStyle.pageSheet => 'page_sheet',
      };
}
