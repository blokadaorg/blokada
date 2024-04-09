import 'package:collection/collection.dart';

extension ListUtils<T> on List<T> {
  T? find(bool Function(T) predicate) => firstWhereOrNull(predicate);
}
