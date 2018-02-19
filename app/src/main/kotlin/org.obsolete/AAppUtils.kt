package org.obsolete

import android.annotation.TargetApi
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.Resources
import com.github.salomonbrys.kodein.instance
import gs.environment.Journal
import gs.environment.inject
import org.blokada.main.AKeepAliveService
import org.blokada.property.Filter
import java.util.*


internal fun registerUncaughtExceptionHandler(ctx: Context) {
    val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
    Thread.setDefaultUncaughtExceptionHandler { thread, ex ->
        restartApplicationThroughService(ctx, 2000)
        defaultHandler.uncaughtException(thread, ex)
    }
}

private fun restartApplicationThroughService(ctx: Context, delayMillis: Int) {
    val alarm: AlarmManager = ctx.inject().instance()

    val restartIntent = Intent(ctx, AKeepAliveService::class.java)
    val intent = PendingIntent.getService(ctx, 0, restartIntent, 0)
    alarm.set(AlarmManager.RTC, System.currentTimeMillis() + delayMillis, intent)

    ctx.inject().instance<Journal>().log("restarting app")
}

internal fun downloadFilters(filters: List<Filter>) {
    filters.forEach { filter ->
        if (filter.hosts.isEmpty()) {
            filter.hosts = filter.source.fetch()
            filter.valid = filter.hosts.isNotEmpty()
        }
    }
}

internal fun combine(blacklist: List<Filter>, whitelist: List<Filter>): Set<String> {
    val set = mutableSetOf<String>()
    blacklist.forEach { set.addAll(it.hosts) }
    whitelist.forEach { set.removeAll(it.hosts) }
    return set
}

@TargetApi(24)
internal fun getPreferredLocales(): List<Locale> {
    val cfg = Resources.getSystem().configuration
    return try {
        // Android, a custom list type that is not an iterable. Just wow.
        val locales = cfg.locales
        (0..locales.size() - 1).map { locales.get(it) }
    } catch (t: Throwable) { listOf(cfg.locale) }
}
