import 'package:mobx/mobx.dart';

// A simple wrapper over MobX's reaction that also checks the store for null.
// As we inject stores using DI, the reaction definitions were hiding error
// in case of when we forget to register it as dependency.
ReactionDisposer reactionOnStore<T>(
    T Function(dynamic) fn, void Function(T) effect,
    {String? name,
    int? delay,
    bool? fireImmediately,
    EqualityComparer<T>? equals,
    ReactiveContext? context,
    void Function(Object, Reaction)? onError}) {
  try {
    // Try the reaction condition to see if it errors out
    fn(null);
  } catch (e) {
    throw ArgumentError('Reaction condition failed to execute, check DI setup');
  }
  return reaction(fn, effect,
      name: name,
      delay: delay,
      fireImmediately: fireImmediately,
      equals: equals,
      context: context,
      onError: onError);
}
