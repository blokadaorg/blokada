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

import blocka.LegacyAccountImport
import model.*
import repository.PackMigration
import tunnel.LegacyAdsCounterImport
import tunnel.LegacyBlocklistImport
import ui.ActivationViewModel
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
                is Denied -> file.save(
                    key = BlocklistService.USER_DENIED,
                    data = newline.serialize(obj)
                )
                is Allowed -> file.save(
                    key = BlocklistService.USER_ALLOWED,
                    data = newline.serialize(obj)
                )
                else -> prefs.save(getPrefsKey(obj::class), json.serialize(obj))
            }
        } catch (ex: Exception) {
            log.e("Could not save persistence, ignoring".cause(ex))
        }
    }

    fun <T: Any> load(type: KClass<T>): T {
        try {
            val (string, deserializer) = when (type) {
                Denied::class -> {
                    val legacy = LegacyBlocklistImport.importLegacyBlocklistUserDenied()
                    if (legacy != null) {
                        save(Denied(legacy)) // To save in the current format
                        legacy.joinToString("\n") to newline
                    } else file.load(key = BlocklistService.USER_DENIED) to newline
                }
                Allowed::class -> {
                    val legacy = LegacyBlocklistImport.importLegacyBlocklistUserAllowed()
                    if (legacy != null) {
                        save(Allowed(legacy)) // To save in the current format
                        legacy.joinToString("\n") to newline
                    } else file.load(key = BlocklistService.USER_ALLOWED) to newline
                }
                Account::class -> {
                    val legacy = LegacyAccountImport.importLegacyAccount()
                    if (legacy != null) {
                        save(legacy) // To save in the current format
                        legacy to PassthroughSerializationService
                    } else prefs.load(getPrefsKey(type)) to json
                }
                AdsCounter::class -> {
                    val legacy = LegacyAdsCounterImport.importLegacyCounter()
                    if (legacy != null) {
                        save(legacy) // To save in the current format
                        legacy to PassthroughSerializationService
                    }
                    else prefs.load(getPrefsKey(type)) to json
                }
                else -> prefs.load(getPrefsKey(type)) to json
            }
            if (string != null) {
                val deserialized = deserializer.deserialize(string, type)
                return when (type) {
                    Packs::class -> {
                        val (packs, migrated) = PackMigration.migrate(deserialized as Packs)
                        if (migrated) save(packs)
                        packs as T
                    }
                    else -> deserialized
                }
            }
            log.v("No persistence, using defaults for: $type")
            return getDefault(type)
        } catch (ex: Exception) {
            log.e("Could not load persistence, restoring defaults for: $type: ${ex.message}")
            return getDefault(type)
        }
    }

    private fun getPrefsKey(type: KClass<*>) = when (type) {
        Stats::class -> "stats"
        Packs::class -> "packs"
        BlockaConfig::class -> "blockaConfig"
        LocalConfig::class -> "localConfig"
        SyncableConfig::class -> "syncableConfig"
        DnsWrapper::class -> "dns"
        ActivationViewModel.ActivationState::class -> "activationState"
        Account::class -> "account"
        AdsCounter::class -> "adsCounter"
        BypassedAppIds::class -> "bypassedApps"
        BlockaRepoConfig::class -> "blockaRepoConfig"
        BlockaRepoUpdate::class -> "blockaRepoUpdate"
        BlockaRepoPayload::class -> "blockaRepoPayload"
        BlockaAfterUpdate::class -> "blockaAfterUpdate"
        else -> throw BlokadaException("Unsupported type for persistence: $type")
    }

    private fun <T: Any> getDefault(type: KClass<T>) = when (type) {
        Stats::class -> Defaults.stats() as T
        Allowed::class -> Defaults.allowed() as T
        Denied::class -> Defaults.denied() as T
        Packs::class -> Defaults.packs() as T
        BlockaConfig::class -> Defaults.blockaConfig() as T
        LocalConfig::class -> Defaults.localConfig() as T
        SyncableConfig::class -> Defaults.syncableConfig() as T
        DnsWrapper::class -> Defaults.dnsWrapper() as T
        ActivationViewModel.ActivationState::class -> ActivationViewModel.ActivationState.INACTIVE as T
        Account::class -> throw NoPersistedAccount()
        AdsCounter::class -> Defaults.adsCounter() as T
        BypassedAppIds::class -> Defaults.bypassedAppIds() as T
        BlockaRepoConfig::class -> Defaults.blockaRepoConfig() as T
        BlockaRepoUpdate::class -> Defaults.noSeenUpdate() as T
        BlockaRepoPayload::class -> Defaults.noPayload() as T
        BlockaAfterUpdate::class -> Defaults.noAfterUpdate() as T
        else -> throw BlokadaException("No default for persisted type: $type")
    }

}