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
import android.os.SystemClock
import androidx.core.app.ActivityCompat
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
     * none is. Comparing it with the flag after the result tells a system
     * auto-denial apart from a prompt the user answered, without persisting
     * any "already asked" state (which Auto Backup would restore on a fresh
     * install, and which goes stale when Android auto-resets the permission).
     */
    private var rationaleBeforeRequest: Boolean? = null

    /**
     * When the request in flight was made. A dismissed first prompt and a
     * prompt Android refused to show both end with no rationale before or
     * after; only the refusal comes back without the user touching anything.
     */
    private var requestedAt = 0L

    // Far below any human answer, far above Android's immediate auto-denial.
    private const val AUTO_DENIAL_MS = 500L

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
        requestedAt = SystemClock.elapsedRealtime()
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
            return
        }

        log.w("Notification permission not granted")
        // No rationale before nor after a denial means Android did not show its
        // prompt (denied twice before), or the user dismissed a first prompt.
        // Only the former is instant; a dismissed prompt can simply be asked again.
        val instant = SystemClock.elapsedRealtime() - requestedAt < AUTO_DENIAL_MS
        val rationaleAfter = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.hasActivityContext() &&
            ActivityCompat.shouldShowRequestPermissionRationale(
                context.requireActivity(), Manifest.permission.POST_NOTIFICATIONS
            )
        if (rationaleBefore == false && !rationaleAfter && instant) onBlockedBySystem()
    }
}
