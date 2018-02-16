package org.blokada.property

import android.content.Context
import com.github.salomonbrys.kodein.instance
import gs.environment.Identity
import gs.environment.identityFrom
import org.blokada.framework.*
import org.blokada.framework.di
import org.blokada.framework.readFromCache
import org.blokada.framework.saveToCache
import java.net.URL
import java.util.*


class APrefsPersistence<T>(
        val ctx: Context,
        val key: String
) : IPersistence<T> {

    val p by lazy { ctx.getSharedPreferences("default", Context.MODE_PRIVATE) }

    override fun read(current: T): T {
        return when (current) {
            is Boolean -> p.getBoolean(key, current)
            is Int -> p.getInt(key, current)
            is Long -> p.getLong(key, current)
            is String -> p.getString(key, current)
            else -> throw Exception("unsupported type for ${key}")
        } as T
    }

    override fun write(source: T) {
        val e = p.edit()
        when(source) {
            is Boolean -> e.putBoolean(key, source)
            is Int -> e.putInt(key, source)
            is Long -> e.putLong(key, source)
            is String -> e.putString(key, source)
            else -> throw Exception("unsupported type for ${key}")
        }
        e.apply()
    }

}

class AIdentityPersistence(
        val ctx: Context
) : IPersistence<Identity> {

    val p by lazy { ctx.getSharedPreferences("AState", Context.MODE_PRIVATE) }

    override fun read(current: Identity): Identity {
        return identityFrom(p.getString("id", ""))
    }

    override fun write(source: Identity) {
        val e = p.edit()
        e.putString("id", source.toString())
        e.apply()
    }

}

class ARepoPersistence(
        val ctx: Context,
        val default: () -> Repo
) : IPersistence<Repo> {

    val p by lazy { ctx.getSharedPreferences("repo", Context.MODE_PRIVATE) }

    override fun read(current: Repo): Repo {
        return try {
            Repo(
                    contentPath = URL(p.getString("contentPath", null)),
                    locales = p.getStringSet("locales", null).map { Locale(it) }.toList(),
                    pages = p.getStringSet("pages", null).map {
                        val parts = it.split("^")
                        Locale(parts[0]) to (URL(parts[1]) to URL(parts[2]))
                    }.toMap(),
                    newestVersionCode = p.getInt("code", 0),
                    newestVersionName = p.getString("name", null),
                    downloadLinks = p.getStringSet("links", null).map { URL(it) }.toList(),
                    lastRefreshMillis = p.getLong("lastRefresh", 0)
            )
        } catch (e: Exception) {
            default()
        }
    }

    override fun write(source: Repo) {
        val e = p.edit()
        e.putString("contentPath", source.contentPath?.toString() ?: "")
        e.putStringSet("locales", source.locales.map { it.toString() }.toSet())
        e.putStringSet("pages", source.pages.map { "${it.key}^${it.value.first}^${it.value.second}" }.toSet())
        e.putInt("code", source.newestVersionCode)
        e.putString("name", source.newestVersionName)
        e.putStringSet("links", source.downloadLinks.map { it.toString() }.toSet())
        e.putLong("lastRefresh", source.lastRefreshMillis)
        e.apply()
    }

}

class AFiltersPersistence(
        val ctx: Context,
        val default: () -> List<Filter>
) : IPersistence<List<Filter>> {

    val p by lazy { ctx.getSharedPreferences("filters", Context.MODE_PRIVATE) }

    override fun read(current: List<Filter>): List<Filter> {
        val s : FilterSerializer = ctx.di().instance()
        val filters = s.deserialise(p.getString("filters", "").split("^"))
        return if (filters.isNotEmpty()) filters else default()
    }

    override fun write(source: List<Filter>) {
        val s : FilterSerializer = ctx.di().instance()
        val e = p.edit()
        e.putInt("migratedVersion", 20)
        e.putString("filters", s.serialise(source).joinToString("^"))
        e.apply()
    }

}

class ACompiledFiltersPersistence(
        val ctx: Context
) : IPersistence<Set<String>> {

    private val cache by lazy { ctx.di().instance<FilterConfig>().cacheFile }

    override fun read(current: Set<String>): Set<String> {
        return try { readFromCache(cache).toSet() } catch (e: Exception) { setOf() }
    }

    override fun write(source: Set<String>) {
        saveToCache(source, cache)
    }

}

class ALocalisedPersistence(
        val ctx: Context,
        val default: () -> Localised
) : IPersistence<Localised> {

    val p by lazy { ctx.getSharedPreferences("localised", Context.MODE_PRIVATE) }

    override fun read(current: Localised): Localised {
        return try {
            Localised(
                    content = URL(p.getString("content", null)),
                    feedback = URL(p.getString("feedback", null)),
                    bug = URL(p.getString("bug", null)),
                    changelog = p.getString("changelog", null),
                    lastRefreshMillis = p.getLong("lastRefresh", 0)
            )
        } catch (e: Exception) {
            default()
        }
    }

    override fun write(source: Localised) {
        val e = p.edit()
        e.putString("content", source.content.toExternalForm())
        e.putString("feedback", source.feedback.toExternalForm())
        e.putString("bug", source.bug.toExternalForm())
        e.putString("changelog", source.changelog)
        e.putLong("lastRefresh", source.lastRefreshMillis)
        e.apply()
    }

}
