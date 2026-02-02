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

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.util.TypedValue
import androidx.annotation.AttrRes
import androidx.annotation.ColorInt
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import model.SystemTunnelRevoked
import model.Uri
import service.ContextService
import androidx.core.net.toUri

fun Context.getPendingIntentForActivity(
    intent: Intent,
    flags: Int,
    requestCode: Int? = null
): PendingIntent {
    // Use a stable, intent-specific request code so extras aren't lost when PendingIntents are reused.
    val code = requestCode ?: intent.hashCode()
    val baseFlags = flags or PendingIntent.FLAG_UPDATE_CURRENT
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        PendingIntent.getActivity(this, code, intent, baseFlags or PendingIntent.FLAG_IMMUTABLE)
    } else {
        PendingIntent.getActivity(this, code, intent, baseFlags)
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

fun now() = System.currentTimeMillis()
