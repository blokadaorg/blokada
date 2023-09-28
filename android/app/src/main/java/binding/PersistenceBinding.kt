/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2023 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import channel.persistence.PersistenceOps
import model.LegacyAccount
import service.FlutterService
import service.JsonSerializationService
import service.PersistenceService
import service.SharedPreferencesStorageService
import utils.Logger

object PersistenceBinding: PersistenceOps {
    private val flutter by lazy { FlutterService }
    private val storage by lazy { SharedPreferencesStorageService }

    init {
        PersistenceOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doSave(
        key: String,
        value: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        // TODO: isSecure flag, isBackup flag
        storage.save(key, value)
        callback(Result.success(Unit))
    }

    override fun doLoad(
        key: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<String>) -> Unit
    ) {
        var result = storage.load(key)
        if (key == "account:jsonAccount") result = handleLegacyAccount(result)
        if (result != null) callback(Result.success(result))
        else callback(Result.failure(Exception("No value for key $key")))
    }

    override fun doDelete(
        key: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<Unit>) -> Unit
    ) {
        // TODO: proper delete
        storage.save(key, "")
        callback(Result.success(Unit))
    }

    // A temporary code to recover the account IDs saved in the old version of the app
    private val log = Logger("Legacy")
    private val legacyPersistence by lazy { PersistenceService }
    private val deserializer by lazy { JsonSerializationService }
    private fun handleLegacyAccount(json: String?): String? {
        var tryRecover = false
        if (json == null) tryRecover = true
        else {
            try {
                val acc = deserializer.deserialize(json, LegacyAccount::class)
                if (!acc.active) tryRecover = true
            } catch (e: Throwable) { }
        }

        if (tryRecover) {
            try {
                val acc = legacyPersistence.load(LegacyAccount::class)
                if (acc.active) {
                    log.v("Recovered legacy account")
                    val oldJson = deserializer.serialize(acc)
                    // To make sure one-time recovery
                    legacyPersistence.save(acc.copy(active = false))
                    return oldJson
                }
            } catch (e: Throwable) {}
        }

        return json
    }
}