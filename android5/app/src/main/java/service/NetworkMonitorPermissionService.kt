/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
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
            Manifest.permission.ACCESS_BACKGROUND_LOCATION
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