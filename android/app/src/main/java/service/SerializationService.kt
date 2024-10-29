/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import model.BlockaAfterUpdate
import model.BlockaConfig
import model.BlockaRepo
import model.BlockaRepoConfig
import model.BlockaRepoPayload
import model.BlockaRepoUpdate
import model.BlokadaException
import model.BypassedAppIds
import model.DnsWrapper
import model.LegacyAccount
import model.LocalConfig
import model.NetworkSpecificConfigs
import model.Packs
import model.SyncableConfig
import repository.TranslationPack
import kotlin.reflect.KClass

interface SerializationService {
    fun serialize(obj: Any): String
    fun <T: Any> deserialize(serialized: Any, type: KClass<T>): T
}

object JsonSerializationService : SerializationService {

    val json = Json {
        ignoreUnknownKeys = true
    }

    override fun serialize(obj: Any): String {
        when (obj) {
            is Packs -> {
                return json.encodeToString(obj);
            }
            is BlockaConfig -> {
                return json.encodeToString(obj);
            }
            is LocalConfig -> {
                return json.encodeToString(obj);
            }
            is SyncableConfig -> {
                return json.encodeToString(obj);
            }
            is DnsWrapper -> {
                return json.encodeToString(obj);
            }
            is BypassedAppIds -> {
                return json.encodeToString(obj);
            }
            is TranslationPack -> {
                return json.encodeToString(obj);
            }
            is BlockaRepo -> {
                return json.encodeToString(obj);
            }
            is BlockaRepoConfig -> {
                return json.encodeToString(obj);
            }
            is BlockaRepoUpdate -> {
                return json.encodeToString(obj);
            }
            is BlockaRepoPayload -> {
                return json.encodeToString(obj);
            }
            is BlockaAfterUpdate -> {
                return json.encodeToString(obj);
            }
            is NetworkSpecificConfigs -> {
                return json.encodeToString(obj);
            }
            is LegacyAccount -> {
                return json.encodeToString(obj);
            }
            else -> throw BlokadaException("Unsupported type for json serialization: ${obj.javaClass}")
        }
    }

    override fun <T: Any> deserialize(serialized: Any, type: KClass<T>): T {
        serialized as String
        when (type) {
            Packs::class -> {
                return json.decodeFromString<Packs>(serialized) as T
            }
            BlockaConfig::class -> {
                return json.decodeFromString<BlockaConfig>(serialized) as T
            }
            LocalConfig::class -> {
                return json.decodeFromString<LocalConfig>(serialized) as T
            }
            SyncableConfig::class -> {
                return json.decodeFromString<SyncableConfig>(serialized) as T
            }
            DnsWrapper::class -> {
                return json.decodeFromString<DnsWrapper>(serialized) as T
            }
            BypassedAppIds::class -> {
                return json.decodeFromString<BypassedAppIds>(serialized) as T
            }
            TranslationPack::class -> {
                return json.decodeFromString<TranslationPack>(serialized) as T
            }
            BlockaRepo::class -> {
                return json.decodeFromString<BlockaRepo>(serialized) as T
            }
            BlockaRepoConfig::class -> {
                return json.decodeFromString<BlockaRepoConfig>(serialized) as T
            }
            BlockaRepoUpdate::class -> {
                return json.decodeFromString<BlockaRepoUpdate>(serialized) as T
            }
            BlockaRepoPayload::class -> {
                return json.decodeFromString<BlockaRepoPayload>(serialized) as T
            }
            BlockaAfterUpdate::class -> {
                return json.decodeFromString<BlockaAfterUpdate>(serialized) as T
            }
            NetworkSpecificConfigs::class -> {
                return json.decodeFromString<NetworkSpecificConfigs>(serialized) as T
            }
            LegacyAccount::class -> {
                return json.decodeFromString<LegacyAccount>(serialized) as T
            }
            else -> throw BlokadaException("Unsupported type for json deserialization: $type")
        }
    }

}

object NewlineSerializationService : SerializationService {
    override fun serialize(obj: Any): String {
        return when (obj) {
            else -> throw BlokadaException("Unsupported type for newline serialization: ${obj.javaClass}")
        }
    }

    override fun <T : Any> deserialize(serialized: Any, type: KClass<T>): T {
        serialized as String
        return when (type) {
            else -> throw BlokadaException("Unsupported type for newline deserialization: $type")
        }
    }

}

object PassthroughSerializationService : SerializationService {

    override fun serialize(obj: Any): String {
        throw BlokadaException("PassthroughSerializationService is only used for legacy import")
    }

    override fun <T: Any> deserialize(serialized: Any, type: KClass<T>): T {
        return serialized as T
    }

}