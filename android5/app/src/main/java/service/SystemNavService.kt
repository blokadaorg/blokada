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

package service

import android.content.Intent
import android.provider.Settings
import androidx.core.content.ContextCompat.startActivity


object SystemNavService {

    private val context = ContextService

    fun openNetworkSettings() {
        val ctx = context.requireContext()
        ctx.startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS));
    }

    fun openNotificationSettings() {
        val ctx = context.requireContext()
        val settingsIntent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
        ctx.startActivity(settingsIntent)
    }

}