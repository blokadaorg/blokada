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
import android.content.pm.PackageManager
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.blokada.R
import utils.Logger

class AppUninstallService {

    private val packageNames = listOf(
        "org.blokada.origin.alarm",
        "org.blokada.alarm.dnschanger",
        "org.blokada.fem.fdroid",
        "org.blokada.sex"
    )

    private val dialog by lazy { DialogService }
    private val ctx by lazy { ContextService }
    private val packageManager by lazy { ctx.requireAppContext().packageManager }

    fun maybePromptToUninstall() {
        val thisApp = ctx.requireAppContext().packageName
        val toUninstall = packageNames - thisApp
        val existing = toUninstall.filter { isPackageInstalled(it) }

        if (hasOtherAppsInstalled()) {
            Logger.w("AppUninstall", "Detected other Blokada, prompting to uninstall")
            showUninstallDialog(existing)
        }
    }

    fun hasOtherAppsInstalled(): Boolean {
        val thisApp = ctx.requireAppContext().packageName
        val toUninstall = packageNames - thisApp
        val existing = toUninstall.filter { isPackageInstalled(it) }

        return existing.isNotEmpty()
    }

    private fun showUninstallDialog(apps: List<String>) {
        GlobalScope.launch(Dispatchers.Main) {
            delay(1000)
            val ctx = ctx.requireAppContext()
            dialog.showAlert(
                message = ctx.getString(R.string.error_multiple_apps),
                header = ctx.getString(R.string.setup_header),
                okText = ctx.getString(R.string.universal_action_continue),
                okAction = { uninstallApps(apps) }
            )
            .collect {  }
        }
    }

    private fun uninstallApps(apps: List<String>) {
        GlobalScope.launch(Dispatchers.Main) {
            delay(1000)
            Logger.w("AppUninstall", "Uninstalling apps")
            apps.forEach {
                val intent = Intent(Intent.ACTION_UNINSTALL_PACKAGE)
                intent.data = Uri.parse("package:$it")
                ctx.requireActivity().startActivity(intent)
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0);
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

}