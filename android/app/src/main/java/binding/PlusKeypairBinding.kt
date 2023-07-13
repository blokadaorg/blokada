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

import channel.pluskeypair.PlusKeypair
import channel.pluskeypair.PlusKeypairOps
import engine.EngineService
import kotlinx.coroutines.flow.MutableStateFlow
import service.FlutterService

object PlusKeypairBinding: PlusKeypairOps {
    val keypair = MutableStateFlow<PlusKeypair?>(null)

    private val flutter by lazy { FlutterService }
    private val engine by lazy { EngineService }

    init {
        PlusKeypairOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doGenerateKeypair(callback: (Result<PlusKeypair>) -> Unit) {
        val keypair = engine.newKeypair()
        val converted = PlusKeypair(
            publicKey = keypair.second,
            privateKey = keypair.first,
        )
        this.keypair.value = converted
        callback(Result.success(converted))
    }

    override fun doCurrentKeypair(keypair: PlusKeypair, callback: (Result<Unit>) -> Unit) {
        this.keypair.value = keypair
        callback(Result.success(Unit))
    }
}