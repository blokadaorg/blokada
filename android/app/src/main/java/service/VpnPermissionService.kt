/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import android.app.Activity
import android.net.VpnService
import utils.Logger

object VpnPermissionService {

    private val log = Logger("VpnPerm")
    private val context by lazy { ContextService }

    var onPermissionGranted = { granted: Boolean -> }

    fun hasPermission(): Boolean {
        return VpnService.prepare(context.requireContext()) == null
    }

    fun askPermission() {
        log.w("Asking for VPN permission")
        val activity = context.requireContext()
        if (activity !is Activity) {
            log.e("No activity context available")
            return
        }

        VpnService.prepare(activity)?.let { intent ->
            activity.startActivityForResult(intent, 0)
        } ?: onPermissionGranted(true)
    }

    fun resultReturned(resultCode: Int) {
        if (resultCode == -1) onPermissionGranted(true)
        else {
            log.w("VPN permission not granted, returned code $resultCode")
            onPermissionGranted(false)
        }
    }

}