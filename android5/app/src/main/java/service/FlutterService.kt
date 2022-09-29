/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import repository.Repos
import ui.home.ShareUtils
import ui.utils.cause
import utils.Logger

object FlutterService {

    private val ctx by lazy { ContextService }

    private val accountIdHot = Repos.account.accountIdHot

    private lateinit var sendAccountId: MethodChannel
    private lateinit var share: MethodChannel

    fun setup() {
        val engine = FlutterEngine(ctx.requireAppContext())
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put("common", engine);

        sendAccountId = MethodChannel(engine.dartExecutor.binaryMessenger, "account:id")
        onAccountIdChanged_SendToFlutter()

        // Share counter
        share = MethodChannel(engine.dartExecutor.binaryMessenger, "share")
        share.setMethodCallHandler { call, result ->
            try {
                val counter = call.arguments as Int
                val counterString = ShareUtils().getCounterString(counter.toLong())
                ShareUtils().shareMessage(ctx.requireContext(), counterString)
            } catch (ex: Exception) {
                Logger.w("FlutterService", "Failed to share counter".cause(ex))
            }
        }

        Logger.v("Flutter", "FlutterEngine initialized")
    }

    private fun sendAccountId(id: String) {
        sendAccountId.invokeMethod("account:id", id);
    }

    private fun onAccountIdChanged_SendToFlutter() {
        GlobalScope.launch(Dispatchers.Main) {
            accountIdHot.collect {
                sendAccountId(it)
            }
        }
    }

}