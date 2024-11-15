part of '../core.dart';

Future<void> sleepAsync(Duration duration) async {
  await Future.delayed(duration);
}
