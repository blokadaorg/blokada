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
import service.FlutterService
import service.SharedPreferencesStorageService

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
        val result = storage.load(key)
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
}