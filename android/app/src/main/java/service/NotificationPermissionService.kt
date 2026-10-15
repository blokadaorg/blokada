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
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import java.io.File
import utils.Logger

/**
 * Runtime POST_NOTIFICATIONS permission (Android 13+). A fresh install starts
 * without it, so it has to be requested before the app may call it denied.
 */
object NotificationPermissionService {

    const val REQUEST_CODE = 1 // 0 is NetworkMonitorPermissionService

    private val log = Logger("NotifPerm")
    private val context = ContextService

    /**
     * Called when Android answered the request without showing its prompt,
     * so only system Settings can grant the permission now. PermsRepo sets it
     * to show the instructions dialog.
     */
    var onBlockedBySystem: () -> Unit = {}

    /**
     * Rationale flag sampled right before the request in flight, or null when
     * none is. Compared with the flag after the result to see what the user did.
     */
    private var rationaleBeforeRequest: Boolean? = null

    /**
     * Marker file: the user has denied the prompt at least once. It lives in
     * noBackupFilesDir so Auto Backup never restores it onto a fresh install,
     * where the prompt is available again. Cleared once the permission is granted.
     */
    private val deniedBeforeFile by lazy {
        File(context.requireAppContext().noBackupFilesDir, "notification_perm_denied")
    }

    /**
     * True when the runtime permission is what blocks notifications and an
     * activity is available to request it. Whether Android still shows its
     * prompt is only known from the result, see [resultReturned]. Granted but
     * with notifications switched off in app settings needs Settings instead.
     */
    fun canAskPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        if (!context.hasActivityContext()) return false
        return ActivityCompat.checkSelfPermission(
            context.requireActivity(), Manifest.permission.POST_NOTIFICATIONS
        ) != PackageManager.PERMISSION_GRANTED
    }

    /** Forget earlier denials once notifications work, e.g. after a grant in Settings. */
    fun onPermissionGranted() {
        deniedBeforeFile.delete()
    }

    fun askPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (!context.hasActivityContext()) {
            log.e("No activity context available")
            return
        }
        val activity = context.requireActivity()

        log.w("Asking for notification permission")
        rationaleBeforeRequest = ActivityCompat.shouldShowRequestPermissionRationale(
            activity, Manifest.permission.POST_NOTIFICATIONS
        )
        ActivityCompat.requestPermissions(
            activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE
        )
    }

    fun resultReturned(result: IntArray) {
        val rationaleBefore = rationaleBeforeRequest
        rationaleBeforeRequest = null

        if (result.isEmpty()) {
            // Interrupted, e.g. by an overlapping request; nothing was decided.
            log.w("Notification permission request cancelled")
            return
        }
        if (result.all { it == PackageManager.PERMISSION_GRANTED }) {
            log.v("Notification permission granted")
            onPermissionGranted()
            return
        }

        log.w("Notification permission not granted")
        val rationaleAfter = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.hasActivityContext() &&
            ActivityCompat.shouldShowRequestPermissionRationale(
                context.requireActivity(), Manifest.permission.POST_NOTIFICATIONS
            )
        val deniedBefore = deniedBeforeFile.exists()
        // Android raises the rationale flag after the first "Don't allow" and drops
        // it again after the second, so either change means the user answered.
        if (rationaleAfter || rationaleBefore == true) {
            deniedBeforeFile.createNewFile()
            return
        }
        // No rationale before or after: Android skipped its prompt because the user
        // denied twice already, or the user dismissed a first prompt. Only a user who
        // has denied before can be in the first case.
        if (rationaleBefore == false && deniedBefore) onBlockedBySystem()
    }
}
