/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package repository

import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import model.Granted
import org.blokada.R
import service.AlertDialogService
import service.ContextService
import service.NotificationService
import service.VpnPermissionService
import utils.Intents

open class PermsRepo {

    private val writeNotificationPerms = MutableStateFlow<Granted?>(null)

    private val notificationPermsHot = writeNotificationPerms.filterNotNull().distinctUntilChanged()

    private val context by lazy { ContextService }
    private val vpnPerms by lazy { VpnPermissionService }
    private val notification by lazy { NotificationService }
    private val dialog by lazy { AlertDialogService }
    private val intents by lazy { Intents }
    private val scope by lazy { CoroutineScope(Dispatchers.Main) }

    private var ongoingVpnPerm: CancellableContinuation<Granted>? = null
        @Synchronized set
        @Synchronized get

    open fun start() {
        onVpnPermsGranted_Proceed()
        scope.launch { writeNotificationPerms.emit(notification.hasPermissions()) }
    }

    private fun onVpnPermsGranted_Proceed() {
        // Also used in AskVpnProfileFragment, but that fragment is
        // not used in Cloud mode, so it won't collide
        vpnPerms.onPermissionGranted = { granted ->
//            GlobalScope.launch { writeNotificationPerms.emit(granted) }
            if (ongoingVpnPerm?.isCompleted == false) {
                ongoingVpnPerm?.resume(granted, {})
                ongoingVpnPerm = null
            }
        }
    }

    suspend fun maybeDisplayNotificationPermsDialog() {
        val granted = notificationPermsHot.first()
        if (!granted) {
            displayNotificationPermsInstructions()
        }
    }

    private fun displayNotificationPermsInstructions() {
        val ctx = context.requireContext()
        dialog.showAlert(
            message = ctx.getString(R.string.notification_perms_denied),
            title = ctx.getString(R.string.notification_perms_header),
            positiveAction = ctx.getString(R.string.dnsprofile_action_open_settings) to {
                val intent = intents.createNotificationSettingsIntent(ctx)
                intents.openIntentActivity(ctx, intent)
            }
        )
    }
}