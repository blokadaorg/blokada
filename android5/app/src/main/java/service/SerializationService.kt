/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import com.squareup.moshi.Moshi
import com.squareup.moshi.adapters.Rfc3339DateJsonAdapter
import model.*
import repository.BlockaRepoRepository
import repository.TranslationPack
import ui.ActivationViewModel
import utils.Logger
import java.util.*
import kotlin.reflect.KClass

interface SerializationService {
    fun serialize(obj: Any): String
    fun <T: Any> deserialize(serialized: Any, type: KClass<T>): T
}

object JsonSerializationService : SerializationService {

    val moshi = Moshi.Builder()
        .add(Date::class.java, Rfc3339DateJsonAdapter())
        .build()

    override fun serialize(obj: Any): String {
        when (obj) {
            is Stats -> {
                val adapter = moshi.adapter(Stats::class.java)
                return adapter.toJson(obj)
            }
            is Packs -> {
                val adapter = moshi.adapter(Packs::class.java)
                return adapter.toJson(obj)
            }
            is BlockaConfig -> {
                val adapter = moshi.adapter(BlockaConfig::class.java)
                return adapter.toJson(obj)
            }
            is LocalConfig -> {
                val adapter = moshi.adapter(LocalConfig::class.java)
                return adapter.toJson(obj)
            }
            is SyncableConfig -> {
                val adapter = moshi.adapter(SyncableConfig::class.java)
                return adapter.toJson(obj)
            }
            is DnsWrapper -> {
                val adapter = moshi.adapter(DnsWrapper::class.java)
                return adapter.toJson(obj)
            }
            is ActivationViewModel.ActivationState -> {
                val adapter = moshi.adapter(ActivationViewModel.ActivationState::class.java)
                return adapter.toJson(obj)
            }
            is Account -> {
                val adapter = moshi.adapter(Account::class.java)
                return adapter.toJson(obj)
            }
            is AdsCounter -> {
                val adapter = moshi.adapter(AdsCounter::class.java)
                return adapter.toJson(obj)
            }
            is BypassedAppIds -> {
                val adapter = moshi.adapter(BypassedAppIds::class.java)
                return adapter.toJson(obj)
            }
            is TranslationPack -> {
                val adapter = moshi.adapter(TranslationPack::class.java)
                return adapter.toJson(obj)
            }
            is BlockaRepo -> {
                val adapter = moshi.adapter(BlockaRepo::class.java)
                return adapter.toJson(obj)
            }
            is BlockaRepoConfig -> {
                val adapter = moshi.adapter(BlockaRepoConfig::class.java)
                return adapter.toJson(obj)
            }
            is BlockaRepoUpdate -> {
                val adapter = moshi.adapter(BlockaRepoUpdate::class.java)
                return adapter.toJson(obj)
            }
            is BlockaRepoPayload -> {
                val adapter = moshi.adapter(BlockaRepoPayload::class.java)
                return adapter.toJson(obj)
            }
            is BlockaAfterUpdate -> {
                val adapter = moshi.adapter(BlockaAfterUpdate::class.java)
                return adapter.toJson(obj)
            }
            else -> throw BlokadaException("Unsupported type for json serialization: ${obj.javaClass}")
        }
    }

    override fun <T: Any> deserialize(serialized: Any, type: KClass<T>): T {
        serialized as String
        when (type) {
            Stats::class -> {
                val adapter = moshi.adapter(Stats::class.java)
                return adapter.fromJson(serialized) as T
            }
            Packs::class -> {
                val adapter = moshi.adapter(Packs::class.java)
                return adapter.fromJson(serialized) as T
            }
            BlockaConfig::class -> {
                val adapter = moshi.adapter(BlockaConfig::class.java)
                return adapter.fromJson(serialized) as T
            }
            LocalConfig::class -> {
                val adapter = moshi.adapter(LocalConfig::class.java)
                return adapter.fromJson(serialized) as T
            }
            SyncableConfig::class -> {
                val adapter = moshi.adapter(SyncableConfig::class.java)
                return adapter.fromJson(serialized) as T
            }
            DnsWrapper::class -> {
                val adapter = moshi.adapter(DnsWrapper::class.java)
                return adapter.fromJson(serialized) as T
            }
            ActivationViewModel.ActivationState::class -> {
                val adapter = moshi.adapter(ActivationViewModel.ActivationState::class.java)
                return adapter.fromJson(serialized) as T
            }
            Account::class -> {
                val adapter = moshi.adapter(Account::class.java)
                return adapter.fromJson(serialized) as T
            }
            AdsCounter::class -> {
                val adapter = moshi.adapter(AdsCounter::class.java)
                return adapter.fromJson(serialized) as T
            }
            BypassedAppIds::class -> {
                val adapter = moshi.adapter(BypassedAppIds::class.java)
                return adapter.fromJson(serialized) as T
            }
            TranslationPack::class -> {
                val adapter = moshi.adapter(TranslationPack::class.java)
                return adapter.fromJson(serialized) as T
            }
            BlockaRepo::class -> {
                val adapter = moshi.adapter(BlockaRepo::class.java)
                return adapter.fromJson(serialized) as T
            }
            BlockaRepoConfig::class -> {
                val adapter = moshi.adapter(BlockaRepoConfig::class.java)
                return adapter.fromJson(serialized) as T
            }
            BlockaRepoUpdate::class -> {
                val adapter = moshi.adapter(BlockaRepoUpdate::class.java)
                return adapter.fromJson(serialized) as T
            }
            BlockaRepoPayload::class -> {
                val adapter = moshi.adapter(BlockaRepoPayload::class.java)
                return adapter.fromJson(serialized) as T
            }
            BlockaAfterUpdate::class -> {
                val adapter = moshi.adapter(BlockaAfterUpdate::class.java)
                return adapter.fromJson(serialized) as T
            }
            else -> throw BlokadaException("Unsupported type for json deserialization: $type")
        }
    }

}

object NewlineSerializationService : SerializationService {
    override fun serialize(obj: Any): String {
        return when (obj) {
            is Allowed -> obj.value.joinToString(separator = "\n")
            is Denied -> obj.value.joinToString(separator = "\n")
            else -> throw BlokadaException("Unsupported type for newline serialization: ${obj.javaClass}")
        }
    }

    override fun <T : Any> deserialize(serialized: Any, type: KClass<T>): T {
        serialized as String
        return when (type) {
            Allowed::class -> Allowed(value = serialized.split("\n").filter { it.isNotBlank() }) as T
            Denied::class -> Denied(value = serialized.split("\n").filter { it.isNotBlank() }) as T
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