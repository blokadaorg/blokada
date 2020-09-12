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

import android.app.Activity
import android.net.VpnService
import utils.Logger

object VpnPermissionService {

    private val log = Logger("VpnPerm")
    private val context = ContextService

    var onPermissionGranted = {}

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
        } ?: onPermissionGranted()
    }

    fun resultReturned(resultCode: Int) {
        if (resultCode == -1) onPermissionGranted()
        else log.w("VPN permission not granted, returned code $resultCode")
    }

}