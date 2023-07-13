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

import channel.notification.NotificationOps
import service.FlutterService
import service.NotificationService
import utils.toBlockaDate

object NotificationBinding: NotificationOps {
    private val flutter by lazy { FlutterService }
    private val notification by lazy { NotificationService }
    private val command by lazy { CommandBinding }

    init {
        NotificationOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doShow(notificationId: String, atWhen: String, callback: (Result<Unit>) -> Unit) {
        notification.show(notificationId, atWhen.toBlockaDate())
        callback(Result.success(Unit))
    }

    override fun doDismissAll(callback: (Result<Unit>) -> Unit) {
        notification.dismissAll()
        callback(Result.success(Unit))
    }
}