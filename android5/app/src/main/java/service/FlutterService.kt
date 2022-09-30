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
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import repository.Repos
import ui.home.ShareUtils
import ui.utils.cause
import utils.Logger
import java.util.*

object FlutterService {

    private val ctx by lazy { ContextService }

    private val accountIdHot = Repos.account.accountIdHot

    private val appStateHot = Repos.app.appStateHot
    private val workingHot = Repos.app.workingHot

    private val appRepo = Repos.app;

    private lateinit var sendAccountId: MethodChannel
    private lateinit var share: MethodChannel
    private lateinit var appState: MethodChannel
    private lateinit var appChangeState: MethodChannel

    fun setup() {
        val engine = FlutterEngine(ctx.requireAppContext())
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put("common", engine);

        // Push account ID changes to Flutter
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

        // Push app state changes to Flutter
        appState = MethodChannel(engine.dartExecutor.binaryMessenger, "app:state")
        onAppStateChanged_SendToFlutter()

        // Change app state
        appChangeState = MethodChannel(engine.dartExecutor.binaryMessenger, "app:changeState")
        appChangeState.setMethodCallHandler { call, result ->
            try {
                val unpause = call.arguments as Boolean
                GlobalScope.launch {
                    if (unpause) appRepo.unpauseApp() else appRepo.pauseApp(Date(0))
                }
            } catch (ex: Exception) {
                Logger.w("FlutterService", "Failed to change app state".cause(ex))
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

    private fun onAppStateChanged_SendToFlutter() {
        GlobalScope.launch(Dispatchers.Main) {
            combine(appStateHot, workingHot) { state, working -> state to working
            }.collect {
                val parsed = "{\"state\":\"${it.first.name.toLowerCase()}\",\"working\":${it.second},\"plus\":false}"
                Logger.v("FlutterService", "Sending app state: $parsed")
                appState.invokeMethod("app:state", parsed)
            }
        }
    }

}