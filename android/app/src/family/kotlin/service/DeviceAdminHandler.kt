/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2025 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class DeviceAdminHandler : DeviceAdminReceiver() {

    private fun showToast(context: Context, msg: String) {
        msg.let { status ->
            Toast.makeText(context, status, Toast.LENGTH_SHORT).show()
        }
    }

    override fun onEnabled(context: Context, intent: Intent) =
        showToast(context, "enabled")

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence =
        "disable requested"

    override fun onDisabled(context: Context, intent: Intent) =
        showToast(context, "disabled")
}
