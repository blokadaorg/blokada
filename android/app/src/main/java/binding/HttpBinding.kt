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

import channel.http.HttpOps
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import service.FlutterService
import service.HttpService

object HttpBinding: HttpOps {
    private val flutter by lazy { FlutterService }
    private val http by lazy { HttpService }

    init {
        HttpOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doGet(url: String, callback: (Result<String>) -> Unit) {
        GlobalScope.async(Dispatchers.IO) {
            try {
                val content = http.makeRequest(url)
                callback(Result.success(content))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun doRequest(
        url: String,
        payload: String?,
        type: String,
        callback: (Result<String>) -> Unit
    ) {
        GlobalScope.async(Dispatchers.IO) {
            try {
                val content = http.makeRequest(url, type, payload)
                callback(Result.success(content))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }
}