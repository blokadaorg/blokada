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

import channel.command.CommandName
import channel.plus.PlusOps
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import service.FlutterService

object PlusBinding: PlusOps {
    val plusEnabled = MutableStateFlow(false)

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }
    private val scope = GlobalScope

    init {
        PlusOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    fun newPlus(gatewayPublicKey: String) {
        scope.launch {
            command.execute(CommandName.NEWPLUS, gatewayPublicKey)
        }
    }

    override fun doPlusEnabledChanged(plusEnabled: Boolean, callback: (Result<Unit>) -> Unit) {
        this.plusEnabled.value = plusEnabled
        callback(Result.success(Unit))
    }
}