import 'package:common/src/core/core.dart';
import 'package:common/src/platform/command/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../tools.dart';

class _MockCommandOps extends Mock implements CommandOps {}

void main() {
  group('CommandStore', () {
    test('onRegister does not accept commands before bootstrap completes', () async {
      await withTrace((m) async {
        final ops = _MockCommandOps();
        when(() => ops.doCanAcceptCommands()).thenAnswer(ignore());

        final store = CommandStore(commandOps: ops);
        store.onRegister();

        verifyNever(() => ops.doCanAcceptCommands());
      });
    });

    test('acceptCommands flushes queued native commands once core bootstrap is ready', () async {
      await withTrace((m) async {
        final ops = _MockCommandOps();
        when(() => ops.doCanAcceptCommands()).thenAnswer(ignore());

        final store = CommandStore(commandOps: ops);
        store.onRegister();

        await store.acceptCommands(m);

        verify(() => ops.doCanAcceptCommands()).called(1);
      });
    });
  });
}
