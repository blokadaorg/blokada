import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../../util/mobx.dart';
import '../../account/account.dart';
import '../../persistence/persistence.dart';
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

abstract class PlusKeypairStoreBase with Store, Logging, Actor {
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
  onRegister(Act act) {
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
  Future<void> onStart(Marker m) async {
    return await log(m).trace("start", (m) async {
      // TODO: needed for family?
      await load(m);
    });
  }

  @action
  Future<void> load(Marker m) async {
    return await log(m).trace("load", (m) async {
      try {
        // throw Exception("test");
        final json = await _persistence.loadOrThrow(_keyKeypair, m);
        final keypair = PlusKeypair(
          publicKey: json['publicKey'],
          privateKey: json['privateKey'],
        );
        _ensureValidKeypair(keypair);
        currentKeypair = keypair;
      } on Exception catch (_) {
        await generate(m);
      }
    });
  }

  @action
  Future<void> generate(Marker m) async {
    return await log(m).trace("generate", (m) async {
      // throw Exception("test");
      final keypair = await _ops.doGenerateKeypair();
      _ensureValidKeypair(keypair);
      await _persistence.save(_keyKeypair, keypair.toJson(), m);
      currentKeypair = keypair;
      await _plus.clearPlus(m);
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
