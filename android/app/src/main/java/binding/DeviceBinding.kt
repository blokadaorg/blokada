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

import channel.device.DeviceOps
import service.EnvironmentService
import service.FlutterService


object DeviceBinding: DeviceOps {
    private val flutter by lazy { FlutterService }

    init {
        DeviceOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doDeviceTagChanged(deviceTag: String, callback: (Result<Unit>) -> Unit) {
        EnvironmentService.deviceTag = deviceTag
        callback(Result.success(Unit))
    }
}