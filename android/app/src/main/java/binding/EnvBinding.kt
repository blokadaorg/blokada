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

import android.os.Build
import channel.env.EnvOps
import channel.env.EnvPayload
import org.blokada.BuildConfig
import service.EnvironmentService
import service.FlutterService

object EnvBinding: EnvOps {
    private val flutter by lazy { FlutterService }
    private val env by lazy { EnvironmentService }

    init {
        EnvOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doGetEnvPayload(callback: (Result<EnvPayload>) -> Unit) {
        callback(Result.success(
            EnvPayload(
                appVersion = BuildConfig.VERSION_NAME,
                osVersion = Build.VERSION.SDK_INT.toString(),
                buildFlavor = env.getFlavor(),
                buildType = BuildConfig.BUILD_TYPE,
                cpu = Build.SUPPORTED_ABIS[0],
                deviceBrand = Build.MANUFACTURER,
                deviceModel = Build.DEVICE,
                deviceName = env.getDeviceAlias()
            )
        ))
    }

    override fun doUserAgentChanged(userAgent: String, callback: (Result<Unit>) -> Unit) {
        // TODO: ignored for now
        callback(Result.success(Unit))
    }
}