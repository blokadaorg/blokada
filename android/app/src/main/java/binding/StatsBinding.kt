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

import channel.stats.StatsOps
import service.FlutterService

object StatsBinding: StatsOps {
    private val flutter by lazy { FlutterService }

    var blocked = ""

    init {
        StatsOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doBlockedCounterChanged(blocked: String, callback: (Result<Unit>) -> Unit) {
        this.blocked = blocked
        callback(Result.success(Unit))
    }
}