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

import channel.app.AppOps
import channel.app.AppStatus
import kotlinx.coroutines.flow.MutableStateFlow
import service.FlutterService

fun AppStatus.isActive(): Boolean {
    return this == AppStatus.ACTIVATEDCLOUD || this == AppStatus.ACTIVATEDPLUS
}

object AppBinding: AppOps {
    val appStatus = MutableStateFlow(AppStatus.UNKNOWN)

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }

    init {
        AppOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    suspend fun pause() {
        command.execute(channel.command.CommandName.PAUSE)
    }

    suspend fun unpause() {
        command.execute(channel.command.CommandName.UNPAUSE)
    }

    override fun doAppStatusChanged(status: AppStatus, callback: (Result<Unit>) -> Unit) {
        this.appStatus.value = status
        callback(Result.success(Unit))
    }
}