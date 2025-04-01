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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import service.ContextService
import service.FlutterService
import utils.Intents

object FamilyBinding : FamilyOps {
    private val flutter by lazy { FlutterService }
    private val context by lazy { ContextService }
    private val intents by lazy { Intents }
    private val scope by lazy { CoroutineScope(Dispatchers.Main) }

    init {
        FamilyOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doShareUrl(url: String, callback: (Result<Unit>) -> Unit) {
        scope.launch(Dispatchers.IO) {
            try {
                val activity = context.requireActivity()
                val intent = intents.createShareTextIntent(activity, url)
                intents.openIntentActivity(activity, intent)
                callback(Result.success(Unit))
            } catch (e: Exception) {
                try {
                    val context = context.requireContext()
                    val intent = intents.createShareTextIntentAlt(url)
                    intents.openIntentActivity(context, intent)
                    callback(Result.success(Unit))
                } catch (ex: Exception) {
                    callback(Result.failure(e))
                }
            }
        }
    }
}