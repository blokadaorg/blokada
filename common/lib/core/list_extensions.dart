part of 'core.dart';

extension ListExtension<T> on List<T> {
  T get randomElement => this[math.Random().nextInt(length)];
}

// extension ListUtils<T> on List<T> {
//   T? find(bool Function(T) predicate) => firstWhereOrNull(predicate);
// }

extension StringUtils on String {
  String short() {
    if (length < 64) return this;
    return "${substring(0, 64)}...";
  }
}
