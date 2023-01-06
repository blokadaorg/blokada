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

package ui.utils

import android.app.PendingIntent
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.util.TypedValue
import android.widget.Toast
import androidx.annotation.AttrRes
import androidx.annotation.ColorInt
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import model.SystemTunnelRevoked
import model.Uri
import org.blokada.R
import service.ContextService
import utils.Logger

object AndroidUtils {

    private val context = ContextService

    fun copyToClipboard(text: String) {
        val ctx = context.requireContext()
        val clipboard = ContextCompat.getSystemService(ctx, ClipboardManager::class.java)
        val clip = ClipData.newPlainText("name", text)
        clipboard?.setPrimaryClip(clip)
        Toast.makeText(ctx, ctx.getString(R.string.universal_status_copied_to_clipboard), Toast.LENGTH_SHORT).show()
    }

}

fun Context.getPendingIntentForService(intent: Intent, flags: Int): PendingIntent {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        PendingIntent.getService(this, 0, intent, flags or PendingIntent.FLAG_IMMUTABLE)
    } else {
        PendingIntent.getService(this, 0, intent, flags)
    }
}

fun Context.getPendingIntentForActivity(intent: Intent, flags: Int): PendingIntent {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        PendingIntent.getActivity(this, 0, intent, flags or PendingIntent.FLAG_IMMUTABLE)
    } else {
        PendingIntent.getActivity(this, 0, intent, flags)
    }
}

fun Context.getPendingIntentForBroadcast(intent: Intent, flags: Int): PendingIntent {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        PendingIntent.getBroadcast(this, 0, intent, flags or PendingIntent.FLAG_IMMUTABLE)
    } else {
        PendingIntent.getBroadcast(this, 0, intent, flags)
    }
}

fun String.cause(ex: Throwable): String {
    return when (ex) {
        is SystemTunnelRevoked -> "$this: ${ex.localizedMessage}"
        else -> {
            val stacktrace = Log.getStackTraceString(ex)
            return "$this: ${ex.localizedMessage}\n$stacktrace"
        }
    }
}

@ColorInt
fun Context.getColorFromAttr(
    @AttrRes attrColor: Int,
    typedValue: TypedValue = TypedValue(),
    resolveRefs: Boolean = true
): Int {
    theme.resolveAttribute(attrColor, typedValue, resolveRefs)
    return typedValue.data
}

fun Fragment.getColor(colorResId: Int): Int {
    return ContextCompat.getColor(requireContext(), colorResId)
}

fun now() = System.currentTimeMillis()

fun openInBrowser(url: Uri) {
    try {
        val ctx = ContextService.requireContext()
        val intent = Intent(Intent.ACTION_VIEW)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.data = android.net.Uri.parse(url)
        ctx.startActivity(intent)
    } catch (ex: Exception) {
        Logger.w("Browser", "Could not open url in browser: $url".cause(ex))
    }
}