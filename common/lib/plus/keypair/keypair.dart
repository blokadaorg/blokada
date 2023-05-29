import 'package:mobx/mobx.dart';

import '../../env/env.dart';
import '../../event.dart';
import '../../persistence/persistence.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
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

abstract class PlusKeypairStoreBase with Store, Traceable, Dependable {
  late final _ops = dep<PlusKeypairOps>();
  late final _event = dep<EventBus>();
  late final _persistence = dep<SecurePersistenceService>();
  late final _env = dep<EnvStore>();

  @override
  attach() {
    depend<PlusKeypairOps>(PlusKeypairOps());
    depend<PlusKeypairStore>(this as PlusKeypairStore);
  }

  @observable
  PlusKeypair? currentKeypair;

  @action
  Future<void> load(Trace parentTrace) async {
    return await traceWith(parentTrace, "load", (trace) async {
      try {
        final json = await _persistence.loadOrThrow(trace, _keyKeypair);
        final keypair = PlusKeypair(
          publicKey: json['publicKey'],
          privateKey: json['privateKey'],
        );
        _ensureValidKeypair(keypair);
        await _env.setDevicePublicKey(trace, keypair.publicKey);
        currentKeypair = keypair;
      } on Exception catch (_) {
        await generate(trace);
      }
    });
  }

  @action
  Future<void> generate(Trace parentTrace) async {
    return await traceWith(parentTrace, "generate", (trace) async {
      final keypair = await _ops.doGenerateKeypair();
      _ensureValidKeypair(keypair);
      await _env.setDevicePublicKey(trace, keypair.publicKey);
      await _persistence.save(trace, _keyKeypair, keypair.toJson());
      currentKeypair = keypair;
      await _event.onEvent(trace, CommonEvent.plusKeypairChanged);
    });
  }

  _ensureValidKeypair(PlusKeypair keypair) {
    if (keypair.publicKey.isEmpty) {
      throw Exception("Public key is empty");
    }
    if (keypair.privateKey.isEmpty) {
      throw Exception("Private key is empty");
    }
  }
}
