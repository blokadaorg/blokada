import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../../util/mobx.dart';
import '../../account/account.dart';
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
  late final _ops = Core.get<PlusKeypairOps>();
  late final _persistence = Core.get<Persistence>(tag: Persistence.secure);
  late final _account = Core.get<AccountStore>();
  late final _plus = Core.get<PlusStore>();

  PlusKeypairStoreBase() {
    _account.addOn(accountIdChanged, generate);

    reactionOnStore((_) => currentKeypair, (currentKeypair) async {
      if (currentKeypair == null) return;
      await _ops.doCurrentKeypair(currentKeypair);
    });
  }

  @override
  onRegister() {
    Core.register<PlusKeypairOps>(getOps());
    Core.register<PlusKeypairStore>(this as PlusKeypairStore);
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
        final json = await _persistence.loadJson(m, _keyKeypair);
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
      await _persistence.saveJson(m, _keyKeypair, keypair.toJson());
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
