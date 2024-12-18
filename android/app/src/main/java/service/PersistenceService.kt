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

import model.BlockaConfig
import model.BlokadaException
import model.BypassedAppIds
import model.Defaults
import model.DnsWrapper
import model.LegacyAccount
import model.LocalConfig
import model.NetworkSpecificConfigs
import model.SyncableConfig
import ui.utils.cause
import utils.Logger
import kotlin.reflect.KClass

object PersistenceService {

    private val log = Logger("Persistence")

    private val json = JsonSerializationService
    private val newline = NewlineSerializationService

    private val prefs = SharedPreferencesStorageService
    private val file = FileStorageService

    fun save(obj: Any) {
        try {
            when (obj) {
                else -> prefs.save(getPrefsKey(obj::class), json.serialize(obj))
            }
        } catch (ex: Exception) {
            log.e("Could not save persistence, ignoring".cause(ex))
        }
    }

    fun <T: Any> load(type: KClass<T>): T {
        try {
            val (string, deserializer) = when (type) {
                else -> prefs.load(getPrefsKey(type)) to json
            }

            if (string != null) {
                val deserialized = deserializer.deserialize(string, type)
                return when (type) {
                    else -> deserialized
                }
            }

            throw BlokadaException("Nothing persisted yet")
        } catch (ex: Exception) {
            log.w("Could not load persistence for: $type, reason: ${ex.message}")
            log.v("Returning defaults for $type")
            return getDefault(type)
        }
    }

    private fun getPrefsKey(type: KClass<*>) = when (type) {
        BlockaConfig::class -> "blockaConfig"
        LocalConfig::class -> "localConfig"
        SyncableConfig::class -> "syncableConfig"
        DnsWrapper::class -> "dns"
        BypassedAppIds::class -> "bypassedApps"
        NetworkSpecificConfigs::class -> "networkSpecificConfigs"
        LegacyAccount::class -> "account"
        else -> throw BlokadaException("Unsupported type for persistence: $type")
    }

    private fun <T: Any> getDefault(type: KClass<T>) = when (type) {
        BlockaConfig::class -> Defaults.blockaConfig() as T
        LocalConfig::class -> Defaults.localConfig() as T
        SyncableConfig::class -> Defaults.syncableConfig() as T
        DnsWrapper::class -> Defaults.dnsWrapper() as T
        BypassedAppIds::class -> Defaults.bypassedAppIds() as T
        NetworkSpecificConfigs::class -> Defaults.noNetworkSpecificConfigs() as T
        else -> throw BlokadaException("No default for persisted type: $type")
    }

}