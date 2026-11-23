import 'dart:convert';

import 'package:common/src/core/core.dart';
import 'package:common/src/features/account/domain/account.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/platform/account/account.dart' as acc;
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../platform/account/account_test.mocks.dart';
import '../../../platform/account/fixtures.dart';
import '../../../tools.dart';

void main() {
  group("AccountActor", () {
    // Restoring a second account whose type, expiry and freemium state match
    // the current one (here: two inactive libre accounts) changes only the ID.
    test("restoreOfAnotherIdUpdatesAccountId", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final persistence = MockPersistence();
        when(
          persistence.loadJson(any, any, isBackup: true),
        ).thenAnswer((_) => Future.value(jsonDecode(fixtureJsonAccountLibre)));
        Core.register<Persistence>(persistence, tag: Persistence.secure);

        final api = MockAccountApi();
        when(
          api.getAccount(any, any),
        ).thenAnswer((_) => Future.value(JsonAccount.fromJson(jsonDecode(fixtureJsonAccount2))));
        Core.register<AccountApi>(api);

        final store = acc.AccountStore();
        Core.register<acc.AccountStore>(store);
        final accountId = AccountId();
        Core.register(accountId);
        final ephemeral = AccountEphemeral();
        Core.register(ephemeral);

        final actor = AccountActor();
        actor.create(m);
        await actor.start(m);

        await store.load(m);
        expect(await accountId.now(), "mockedmocked");

        // PaymentActor identifies the account to Adapty on this value changing.
        final identified = <String>[];
        ephemeral.onChange.listen((it) => identified.add(it.now.id));

        await store.restore("mocked2", m);

        expect(store.account!.id, "mocked2");
        expect(await accountId.now(), "mocked2");
        expect((await ephemeral.now()).id, "mocked2");
        expect(identified, ["mocked2"]);
      });
    });
  });
}
