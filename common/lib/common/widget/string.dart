extension StringExtension on String {
  String firstLetterUppercase() {
    if (isEmpty) {
      return this;
    }
    return this[0].toUpperCase() + substring(1);
  }
}
