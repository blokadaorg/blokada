import 'package:common/src/core/core.dart';
import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/toast/domain/toast.dart';
import 'package:common/src/features/toast/ui/toast_host.dart';
import 'package:common/src/shared/ui/blokada_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';

/// Records haptic calls made through the platform channel.
List<String> _recordHaptics() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
      return null;
    },
  );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

class _FakeCustomlistApi extends CustomlistApi {
  bool fail = false;
  final List<JsonCustomList> stored = [];

  @override
  Future<List<JsonCustomList>> fetchForProfile(Marker m, {String? profileId}) async =>
      stored.toList();

  @override
  Future<void> add(Marker m, JsonCustomList entry, {String? profileId}) async {
    if (fail) throw Exception('network down');
    stored.add(entry);
  }

  @override
  Future<void> delete(Marker m, JsonCustomList entry, {String? profileId}) async {
    if (fail) throw Exception('network down');
    stored.removeWhere((e) => e.domainName == entry.domainName && e.wildcard == entry.wildcard);
  }
}

void _registerToast() {
  Core.register<ToastValue>(ToastValue());
  Core.register<ToastActor>(ToastActor());
}

_FakeCustomlistApi _registerCustomlist() {
  final api = _FakeCustomlistApi();
  Core.register<CustomListsValue>(CustomListsValue());
  Core.register<CustomlistApi>(api);
  Core.register<CustomlistActor>(CustomlistActor());
  return api;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToastActor', () {
    test('show sets the message with a light haptic', () async {
      final haptics = _recordHaptics();
      await withTrace((m) async {
        _registerToast();
        Core.get<ToastActor>().show('Saved');

        final message = Core.get<ToastValue>().now!;
        expect(message.text, 'Saved');
        expect(message.isError, isFalse);
        expect(haptics, ['HapticFeedbackType.lightImpact']);
      });
    });

    test('showing the same text twice gives two distinct messages', () async {
      await withTrace((m) async {
        _registerToast();
        final updates = <ToastMessage?>[];
        final sub = Core.get<ToastValue>().onChange.listen((u) => updates.add(u.now));

        Core.get<ToastActor>().show('Saved');
        Core.get<ToastActor>().show('Saved');
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(updates.length, 2);
        expect(updates[0]!.id, isNot(updates[1]!.id));
      });
    });

    test('showError marks the message as an error', () async {
      await withTrace((m) async {
        _registerToast();
        Core.get<ToastActor>().showError('Failed');
        expect(Core.get<ToastValue>().now!.isError, isTrue);
      });
    });
  });

  group('CustomlistActor confirmations', () {
    test('adding and removing confirm with the list name', () async {
      await withTrace((m) async {
        _registerToast();
        _registerCustomlist();
        final actor = Core.get<CustomlistActor>();
        final toast = Core.get<ToastValue>();

        await actor.addOrRemove('example.com', false, m, gotBlocked: true);
        expect(toast.now!.text, 'activity action added to whitelist'.i18n);

        await actor.addOrRemove('example.com', false, m, gotBlocked: true);
        expect(toast.now!.text, 'toast removed from allowed'.i18n);

        await actor.addOrRemove('ads.example.com', false, m, gotBlocked: false);
        expect(toast.now!.text, 'activity action added to blacklist'.i18n);

        await actor.remove(m, 'ads.example.com', false);
        expect(toast.now!.text, 'toast removed from blocked'.i18n);
        expect(toast.now!.isError, isFalse);
      });
    });

    test('a removal can stay silent when another change follows', () async {
      await withTrace((m) async {
        _registerToast();
        _registerCustomlist();
        final actor = Core.get<CustomlistActor>();
        await actor.addOrRemove('example.com', false, m, gotBlocked: true);
        final before = Core.get<ToastValue>().now;

        await actor.remove(m, 'example.com', false, confirm: false);
        expect(Core.get<ToastValue>().now, same(before));
        expect(actor.contains('example.com'), isFalse);
      });
    });

    test('removing an entry that is on neither list shows nothing', () async {
      await withTrace((m) async {
        _registerToast();
        _registerCustomlist();
        final shown = <ToastMessage?>[];
        final sub = Core.get<ToastValue>().onChange.listen((u) => shown.add(u.now));

        await Core.get<CustomlistActor>().remove(m, 'missing.example.com', false);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(shown, isEmpty);
      });
    });

    test('a failed change shows an error, restores the list and rethrows', () async {
      await withTrace((m) async {
        _registerToast();
        final api = _registerCustomlist();
        final actor = Core.get<CustomlistActor>();
        api.fail = true;

        await expectLater(
          actor.addOrRemove('example.com', false, m, gotBlocked: true),
          throwsException,
        );

        final message = Core.get<ToastValue>().now!;
        expect(message.isError, isTrue);
        expect(message.text, 'toast save failed'.i18n);
        expect(actor.contains('example.com'), isFalse);
      });
    });
  });

  group('ToastHost', () {
    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ToastHost(child: SizedBox())));
    }

    testWidgets('shows a toast and hides it after two seconds', (tester) async {
      await withTrace((m) async {
        _registerToast();
        await pumpHost(tester);

        Core.get<ToastActor>().show('Copied');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Copied'), findsOneWidget);

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Copied'), findsNothing);
      });
    });

    testWidgets('errors stay longer than confirmations', (tester) async {
      await withTrace((m) async {
        _registerToast();
        await pumpHost(tester);

        Core.get<ToastActor>().showError('Failed');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2500));
        expect(find.text('Failed'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text('Failed'), findsNothing);
      });
    });
  });

  group('BlokadaSwitch', () {
    testWidgets('a flip gives a selection click and reports the new value', (tester) async {
      final haptics = _recordHaptics();
      bool? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: BlokadaSwitch(value: false, onChanged: (v) => reported = v)),
        ),
      );

      await tester.tap(find.byType(BlokadaSwitch));
      await tester.pump();

      expect(reported, isTrue);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('a disabled switch gives no haptic', (tester) async {
      final haptics = _recordHaptics();
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: BlokadaSwitch(value: false, onChanged: null))),
      );

      await tester.tap(find.byType(BlokadaSwitch));
      await tester.pump();

      expect(haptics, isEmpty);
    });
  });
}
