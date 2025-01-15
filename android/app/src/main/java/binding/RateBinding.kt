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

import channel.rate.RateOps
import service.FlutterService

object RateBinding: RateOps {
    private val flutter by lazy { FlutterService }

    var onShowRateDialog: () -> Unit = { }

    init {
        RateOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doShowRateDialog(callback: (Result<Unit>) -> Unit) {
        onShowRateDialog()
        callback(Result.success(Unit))
    }
}