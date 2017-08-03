package org.blokada.ui.app.android

import android.content.Context
import org.blokada.app.IFilterSource
import org.blokada.app.android.FilterSourceLink
import org.blokada.app.android.FilterSourceUri
import org.blokada.framework.IEnvironment
import org.blokada.lib.ui.R
import java.util.*


internal fun Context.getRandomString(stringArray: Int, name: Int? = null): String {
    val strings = resources.getStringArray(stringArray)
    val i = Random().nextInt(strings.size)
    if (name == null) {
        return strings[i]
    } else {
        val n = resources.getString(name)
        return String.format(strings[i], n)
    }
}

fun Context.getBrandedString(resId: Int): String {
    return getString(resId, getString(R.string.branding_app_name_short))
}

internal fun sourceToName(ctx: android.content.Context, source: IFilterSource): String {
    val name = when (source) {
        is FilterSourceLink -> {
            ctx.getString(R.string.filter_name_link, source.source?.host
                    ?: ctx.getString(R.string.filter_name_link_unknown))
        }
        is FilterSourceUri -> {
            ctx.getString(R.string.filter_name_file, source.source?.lastPathSegment
                    ?: ctx.getString(R.string.filter_name_file_unknown))
        }
        else -> null
    }

    return name ?: source.toString()
}

internal fun canShowNotification(last: Long, env: IEnvironment, cooldownMillis: Long): Boolean {
    return last + cooldownMillis < env.now()
}
