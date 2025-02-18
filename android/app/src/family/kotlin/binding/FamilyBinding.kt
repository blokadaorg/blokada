/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2025 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import channel.family.FamilyOps
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import service.FlutterService

// TODO: Include only in Family targets
object FamilyBinding: FamilyOps {
    private val flutter by lazy { FlutterService }
    private val share by lazy { ShareUtil }

    init {
        FamilyOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doShareUrl(url: String, callback: (Result<Unit>) -> Unit) {
        GlobalScope.launch(Dispatchers.IO) {
            try {
                share.shareText(url)
                callback(Result.success(Unit))
            } catch (e: Exception) {
                try {
                    share.shareTextLegacy(url)
                    callback(Result.success(Unit))
                } catch (ex: Exception) {
                    callback(Result.failure(e))
                }
            }
        }
    }
}