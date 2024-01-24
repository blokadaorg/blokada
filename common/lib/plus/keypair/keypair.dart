import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../persistence/persistence.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../../util/trace.dart';
import '../plus.dart';
import 'channel.act.dart';
import 'channel.pg.dart';

part 'keypair.g.dart';

const String _keyKeypair = "plus:keypair";

extension PlusKeypairExt on PlusKeypair {
  toJson() => {
        'publicKey': publicKey,
        'privateKey': privateKey,
      };
}

class PlusKeypairStore = PlusKeypairStoreBase with _$PlusKeypairStore;

abstract class PlusKeypairStoreBase
    with Store, Traceable, Dependable, Startable {
  late final _ops = dep<PlusKeypairOps>();
  late final _persistence = dep<SecurePersistenceService>();
  late final _account = dep<AccountStore>();
  late final _plus = dep<PlusStore>();

  PlusKeypairStoreBase() {
    _account.addOn(accountIdChanged, generate);

    reactionOnStore((_) => currentKeypair, (currentKeypair) async {
      if (currentKeypair == null) return;
      await _ops.doCurrentKeypair(currentKeypair);
    });
  }

  @override
  attach(Act act) {
    depend<PlusKeypairOps>(getOps(act));
    depend<PlusKeypairStore>(this as PlusKeypairStore);
  }

  @observable
  PlusKeypair? currentKeypair;

  @computed
  String get currentDevicePublicKey {
    final key = currentKeypair?.publicKey;
    if (key == null) {
      throw Exception("No device public key set yet");
    }
    return key;
  }

  @override
  @action
  Future<void> start(Trace parentTrace) async {
    return await traceWith(parentTrace, "start", (trace) async {
      // TODO: needed for family?
      await load(trace);
    });
  }

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      try {
        // throw Exception("test");
        final json = await _persistence.loadOrThrow(trace, _keyKeypair);
        final keypair = PlusKeypair(
          publicKey: json['publicKey'],
          privateKey: json['privateKey'],
        );
        _ensureValidKeypair(keypair);
        currentKeypair = keypair;
      } on Exception catch (_) {
        await generate(trace);
      }
    });
  }

  @action
  Future<void> generate(Trace parentTrace) async {
    return await traceWith(parentTrace, "generate", (trace) async {
      // throw Exception("test");
      final keypair = await _ops.doGenerateKeypair();
      _ensureValidKeypair(keypair);
      await _persistence.save(trace, _keyKeypair, keypair.toJson());
      currentKeypair = keypair;
      await _plus.clearPlus(trace);
    });
  }

  _ensureValidKeypair(PlusKeypair keypair) {
    if (keypair.publicKey.isEmpty) {
      throw Exception("Public key is empty");
    }
    if (keypair.privateKey.isEmpty) {
      throw Exception("Private key is empty");
    }
    if (keypair.publicKey == "pk-mocked") {
      throw Exception("Public key is mocked");
    }
    if (keypair.privateKey == "sk-mocked") {
      throw Exception("Private key is mocked");
    }
  }
}
