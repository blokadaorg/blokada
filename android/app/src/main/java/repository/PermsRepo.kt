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
import model.Granted
import org.blokada.R
import service.AlertDialogService
import service.ContextService
import service.NotificationPermissionService
import service.NotificationService
import service.VpnPermissionService
import utils.Intents

open class PermsRepo {

    private val context by lazy { ContextService }
    private val vpnPerms by lazy { VpnPermissionService }
    private val notification by lazy { NotificationService }
    private val notificationPerms by lazy { NotificationPermissionService }
    private val dialog by lazy { AlertDialogService }
    private val intents by lazy { Intents }

    private var ongoingVpnPerm: CancellableContinuation<Granted>? = null
        @Synchronized set
        @Synchronized get

    open fun start() {
        onVpnPermsGranted_Proceed()
    }

    private fun onVpnPermsGranted_Proceed() {
        // Also used in AskVpnProfileFragment, but that fragment is
        // not used in Cloud mode, so it won't collide
        vpnPerms.onPermissionGranted = { granted ->
            if (ongoingVpnPerm?.isCompleted == false) {
                ongoingVpnPerm?.resume(granted, {})
                ongoingVpnPerm = null
            }
        }
    }

    fun maybeDisplayNotificationPermsDialog() {
        // Read live: the user may have granted it in system Settings since app start.
        if (notification.hasPermissions()) return

        if (notificationPerms.canAskPermission()) {
            notificationPerms.askPermission()
        } else {
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