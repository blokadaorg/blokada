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

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import utils.Logger

object NetworkMonitorPermissionService {

    private val log = Logger("NetPerm")
    private val context = ContextService

    private val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        arrayOf(
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.ACCESS_FINE_LOCATION,
            //Manifest.permission.ACCESS_BACKGROUND_LOCATION
        )
    } else {
        arrayOf(
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
    }

    var onPermissionGranted = {}

    fun hasPermission(): Boolean {
        val ctx = context.requireContext()
        return perms.map {
            ActivityCompat.checkSelfPermission(ctx, it)
        }.all {
            it == PackageManager.PERMISSION_GRANTED
        }
    }

    fun askPermission() {
        log.w("Asking for network monitor permission")
        val activity = context.requireContext()
        if (activity !is Activity) {
            log.e("No activity context available")
            return
        }

        ActivityCompat.requestPermissions(activity, perms, 0)
    }

    fun resultReturned(result: IntArray) {
        if (result.all { it == PackageManager.PERMISSION_GRANTED }) {
            log.v("Network monitor permission granted")
            onPermissionGranted()
        } else log.w("Network monitor permission not granted")
    }

}