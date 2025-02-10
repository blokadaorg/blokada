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
import channel.common.CommonOps
import channel.common.OpsEnvInfo
import channel.common.OpsLink
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import org.blokada.BuildConfig
import service.EnvironmentService
import service.FlutterService
import service.HttpService
import service.NotificationService
import utils.toBlockaDate

object CommonBinding: CommonOps {
    private val flutter by lazy { FlutterService }
    private val env by lazy { EnvironmentService }

    init {
        CommonOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    // Env

    override fun doGetEnvInfo(callback: (Result<OpsEnvInfo>) -> Unit) {
        callback(Result.success(
            OpsEnvInfo(
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

    // Notification

    private val notification by lazy { NotificationService }

    override fun doShow(
        notificationId: String,
        atWhen: String,
        body: String?,
        callback: (Result<Unit>) -> Unit
    ) {
        notification.show(notificationId, atWhen.toBlockaDate(), body)
        callback(Result.success(Unit))
    }

    override fun doDismissAll(callback: (Result<Unit>) -> Unit) {
        notification.dismissAll()
        callback(Result.success(Unit))
    }

    // Rate

    var onShowRateDialog: () -> Unit = { }

    override fun doShowRateDialog(callback: (Result<Unit>) -> Unit) {
        onShowRateDialog()
        callback(Result.success(Unit))
    }

    // Http

    private val http by lazy { HttpService }

    override fun doGet(url: String, callback: (Result<String>) -> Unit) {
        GlobalScope.async(Dispatchers.IO) {
            try {
                val content = http.makeRequest(url)
                callback(Result.success(content))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun doRequest(
        url: String,
        payload: String?,
        type: String,
        callback: (Result<String>) -> Unit
    ) {
        GlobalScope.async(Dispatchers.IO) {
            try {
                val content = http.makeRequest(url, type, payload)
                callback(Result.success(content))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun doRequestWithHeaders(
        url: String,
        payload: String?,
        type: String,
        headers: Map<String?, String?>,
        callback: (Result<String>) -> Unit
    ) {
        GlobalScope.async(Dispatchers.IO) {
            try {
                val h = headers.mapKeys { it.key!! }.mapValues { it.value!! }

                val content = http.makeRequest(url, type, payload, h)
                callback(Result.success(content))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    // Link

    val links: MutableMap<String, String> = mutableMapOf()

    override fun doLinksChanged(links: List<OpsLink>, callback: (Result<Unit>) -> Unit) {
        this.links.clear()
        links.forEach { link -> this.links[link.id] = link.url }
        callback(Result.success(Unit))
    }
}