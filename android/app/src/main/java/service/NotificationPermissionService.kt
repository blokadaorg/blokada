/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2026 Blocka AB. All rights reserved.
 */

package service

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import utils.Logger

/**
 * Runtime POST_NOTIFICATIONS permission (Android 13+). A fresh install starts
 * without it, so it has to be requested before the app may call it denied.
 */
object NotificationPermissionService {

    const val REQUEST_CODE = 1 // 0 is NetworkMonitorPermissionService

    private const val KEY_REQUESTED = "notificationPermsRequested"

    private val log = Logger("NotifPerm")
    private val context = ContextService

    private val prefs by lazy {
        context.requireContext().getSharedPreferences("local", Context.MODE_PRIVATE)
    }

    /**
     * True when the system prompt can still be shown: the permission exists on
     * this Android version, is not granted, and was never requested or was
     * denied only once. After a second denial Android stops showing the prompt,
     * and only system Settings can grant it. Granted but with notifications
     * switched off in app settings also needs Settings.
     */
    fun canAskPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        val activity = context.requireContext() as? Activity ?: return false
        val granted = ActivityCompat.checkSelfPermission(
            activity, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return false
        if (!prefs.getBoolean(KEY_REQUESTED, false)) return true
        return ActivityCompat.shouldShowRequestPermissionRationale(
            activity, Manifest.permission.POST_NOTIFICATIONS
        )
    }

    fun askPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val activity = context.requireContext()
        if (activity !is Activity) {
            log.e("No activity context available")
            return
        }

        log.w("Asking for notification permission")
        prefs.edit().putBoolean(KEY_REQUESTED, true).apply()
        ActivityCompat.requestPermissions(
            activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE
        )
    }

    fun resultReturned(result: IntArray) {
        if (result.isNotEmpty() && result.all { it == PackageManager.PERMISSION_GRANTED }) {
            log.v("Notification permission granted")
        } else log.w("Notification permission not granted")
    }
}
