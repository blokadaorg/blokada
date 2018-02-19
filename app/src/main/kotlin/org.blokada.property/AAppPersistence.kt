package org.blokada.property

import android.content.Context
import com.github.salomonbrys.kodein.instance
import gs.environment.Identity
import gs.environment.identityFrom
import gs.environment.inject
import gs.property.readFromCache
import gs.property.saveToCache
import org.obsolete.IPersistence


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


class AFiltersPersistence(
        val ctx: Context,
        val default: () -> List<Filter>
) : IPersistence<List<Filter>> {

    val p by lazy { ctx.getSharedPreferences("filters", Context.MODE_PRIVATE) }

    override fun read(current: List<Filter>): List<Filter> {
        val s : FilterSerializer = ctx.inject().instance()
        val filters = s.deserialise(p.getString("filters", "").split("^"))
        return if (filters.isNotEmpty()) filters else default()
    }

    override fun write(source: List<Filter>) {
        val s : FilterSerializer = ctx.inject().instance()
        val e = p.edit()
        e.putInt("migratedVersion", 20)
        e.putString("filters", s.serialise(source).joinToString("^"))
        e.apply()
    }

}

class ACompiledFiltersPersistence(
        val ctx: Context
) : IPersistence<Set<String>> {

    private val cache by lazy { ctx.inject().instance<FilterConfig>().cacheFile }

    override fun read(current: Set<String>): Set<String> {
        return try { readFromCache(cache).toSet() } catch (e: Exception) { setOf() }
    }

    override fun write(source: Set<String>) {
        saveToCache(source, cache)
    }

}

