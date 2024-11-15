part of '../core.dart';

extension ListExtension<T> on List<T> {
  T get randomElement => this[math.Random().nextInt(length)];
}
