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
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import model.Granted
import org.blokada.R
import service.ContextService
import service.DialogService
import service.NotificationService
import service.SystemNavService
import service.VpnPermissionService

open class PermsRepo {

    private val writeNotificationPerms = MutableStateFlow<Granted?>(null)

    val notificationPermsHot = writeNotificationPerms.filterNotNull().distinctUntilChanged()

    private val context by lazy { ContextService }
    private val vpnPerms by lazy { VpnPermissionService }
    private val notification by lazy { NotificationService }

    private val dialog = DialogService
    private val systemNav = SystemNavService


    private var ongoingVpnPerm: CancellableContinuation<Granted>? = null
        @Synchronized set
        @Synchronized get

    open fun start() {
        onVpnPermsGranted_Proceed()
        GlobalScope.launch { writeNotificationPerms.emit(notification.hasPermissions()) }
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
            .collect {

            }
        }
    }

    suspend fun displayNotificationPermsInstructions(): Flow<Boolean> {
        val ctx = context.requireContext()
        return dialog.showAlert(
            message = ctx.getString(R.string.notification_perms_denied),
            header = ctx.getString(R.string.notification_perms_header),
            okText = ctx.getString(R.string.dnsprofile_action_open_settings),
            okAction = {
                systemNav.openNotificationSettings()
            }
        )
    }
}