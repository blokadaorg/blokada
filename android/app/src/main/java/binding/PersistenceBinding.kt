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

import android.content.Context
import android.content.SharedPreferences
import androidx.preference.PreferenceManager
import channel.persistence.PersistenceOps
import model.BlokadaException
import model.LegacyAccount
import service.ContextService
import service.FlutterService
import service.JsonSerializationService
import service.PersistenceService
import utils.Logger

object PersistenceBinding: PersistenceOps {
    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }

    private val backedUpSharedPreferences by lazy {
        PreferenceManager.getDefaultSharedPreferences(context.requireContext())
    }

    private val localSharedPreferences by lazy {
        val ctx = context.requireContext()
        ctx.getSharedPreferences("local", Context.MODE_PRIVATE)
    }

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
        if (isBackup) {
            backedUpSharedPreferences.save(key, value)
        } else {
            localSharedPreferences.save(key, value)
        }
        callback(Result.success(Unit))
    }

    private fun SharedPreferences.save(key: String, value: String) {
        val edit = this.edit()
        edit.putString(key, value)
        edit.commit() || throw BlokadaException("Could not save $key to SharedPreferences")
    }

    override fun doLoad(
        key: String,
        isSecure: Boolean,
        isBackup: Boolean,
        callback: (Result<String>) -> Unit
    ) {
        var result = if (isBackup) {
            backedUpSharedPreferences.getString(key, null)
        } else {
            localSharedPreferences.getString(key, null)
        }

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
        if (isBackup) {
            backedUpSharedPreferences.edit().remove(key).commit()
        } else {
            localSharedPreferences.edit().remove(key).commit()
        }
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