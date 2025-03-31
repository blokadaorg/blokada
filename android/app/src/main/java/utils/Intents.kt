/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package utils

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import androidx.core.app.ShareCompat
import androidx.core.content.FileProvider
import model.Uri
import androidx.core.net.toUri
import org.blokada.R
import java.io.File

object Intents {
    fun createOpenInBrowserIntent(url: Uri): Intent {
        val intent = Intent(Intent.ACTION_VIEW)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.data = url.toUri()
        return intent
    }

    fun createShareTextIntent(activity: Activity, text: String): Intent {
        return ShareCompat.IntentBuilder.from(activity)
            .setType("text/plain")
            .setText(text)
            .createChooserIntent()
    }

    fun createShareTextIntentAlt(text: String): Intent {
        val intent = Intent(Intent.ACTION_SEND)
        // Flags left from sharing log file, not sure if needed
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.type = "text/plain"
        intent.putExtra(Intent.EXTRA_TEXT, text)
        return intent
    }

    fun createShareFileIntent(ctx: Context, file: File): Intent {
        val actualUri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.files", file)

        if (ctx is Activity) {
            val activity = ctx as Activity
            return ShareCompat.IntentBuilder.from(activity)
                .setStream(actualUri)
                .setType("text/*")
                .intent
                .setAction(Intent.ACTION_SEND)
                .setDataAndType(actualUri, "text/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        } else {
            val intent = Intent(Intent.ACTION_SEND)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.type = "plain/*"
            intent.putExtra(Intent.EXTRA_STREAM, actualUri)
            return intent
        }
    }

    fun createNetworkSettingsIntent(ctx: Context): Intent {
        // They broke the direct link to settings
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            return Intent(Settings.ACTION_SETTINGS)
        } else {
            return Intent(Settings.ACTION_WIRELESS_SETTINGS)
        }
    }

    fun createNotificationSettingsIntent(ctx: Context): Intent {
        return Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
    }

    fun openIntentActivity(ctx: Context, intent: Intent, title: String? = null) {
        try {
            val options = ctx.packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
            if (options.size > 1) {
                // Show chooser (as per Android security recommendations)
                val chooser =
                    Intent.createChooser(
                        intent,
                        title ?: ctx.getString(R.string.universal_action_continue)
                    )
                ctx.startActivity(chooser)
            } else {
                ctx.startActivity(intent)
            }
        } catch (ex: Exception) {
            Logger.e("Intents", "Could not start activity".cause(ex))
        }
    }
}
