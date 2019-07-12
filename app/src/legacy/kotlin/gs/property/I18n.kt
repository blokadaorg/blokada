package gs.property

import android.content.Context
import android.content.res.Resources
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import core.Format
import core.ktx
import gs.environment.Environment
import gs.environment.Worker
import gs.main.getPreferredLocales
import org.blokada.R
import java.util.*

abstract class I18n {
    abstract val locale: IProperty<String>
    abstract val localised: (key: Any) -> String
    abstract val localisedOrNull: (key: Any) -> String?
    abstract val set: (key: Any, value: String) -> Unit
    abstract fun getString(resId: Int): String
    abstract fun getString(resId: Int, vararg arguments: Any): String
    abstract fun getQuantityString(resId: Int, quantity: Int, vararg arguments: Any): String
    abstract fun contentUrl(): String
    abstract fun fallbackContentUrl(): String
}

typealias LanguageTag = String
typealias Key = String
typealias Localised = String

class I18nImpl (
        private val kctx: Worker,
        private val xx: Environment
) : I18n() {

    private val ctx: Context by xx.instance()
    private val repo: Repo by xx.instance()
    private val res: Resources by lazy { ctx.resources }

    override fun contentUrl(): String {
        return "%s/%s".format(repo.content().contentPath ?: "http://localhost", locale())
    }

    override fun fallbackContentUrl(): String {
        return "%s/%s".format(repo.content().contentPath ?: "http://localhost", "en")
    }

    override val locale = newPersistedProperty(kctx, BasicPersistence(xx, "locale"), { "en" },
            refresh = {
                val ktx = "i18n:locale:refresh".ktx()
                val preferred = getPreferredLocales()
                val available = repo.content().locales
                ktx.v("locale preferred/available", preferred, available)

                /**
                 * Try matching exactly, if not, try matching by language tag. Use order of preferred
                 * locales defined by user.
                 */
                val availableLanguageTags = available.map { Locale(it.language) to it }.toMap()
                val matches = preferred.asSequence().map {
                    val justLanguageTag = Locale(it.language)
                    val tagAndCountry = Locale(it.language, it.country)
                    when {
                        available.contains(it) -> it
                        available.contains(tagAndCountry) -> tagAndCountry
                        available.contains(justLanguageTag) -> justLanguageTag
                        availableLanguageTags.containsKey(justLanguageTag) -> availableLanguageTags[justLanguageTag]
                        else -> null
                    }
                }.filterNotNull()
                ktx.v("locale matches", matches)
                (matches.firstOrNull() ?: Locale("en")).toString()
            })

    private val localisedMap: MutableMap<LanguageTag, MutableMap<Key, Localised>> = mutableMapOf()

    override val localised = { key: Any ->
        localisedOrNull(key) ?: key.toString()
    }

    override val localisedOrNull = { key: Any ->
        // Map resId to actual string key defined in xml files since we use them dynamically
        val (isResource, realKey) = if (key is Int) true to res.getResourceName(key) else false to key.toString()

        // Get all cached translations for current locale
        val strings = localisedMap.getOrPut(locale(), { mutableMapOf<Key, Localised>() })

        // If cache miss, try getting it from resources
        var string = strings.get(realKey)
        if (string == null || isResource) {
            val id = res.getIdentifier(realKey, "string", ctx.packageName)
            if (id != 0) {
                string = res.getString(id)
                strings.put(realKey, string)
            }
        }
        string
    }

    private val persistence: (LanguageTag) -> Persistence<Map<Key, LanguageTag>> = { tag ->
        xx().with(tag).instance<I18nPersistence>()
    }

    override val set: (key: Any, value: String) -> Unit
        get() = { key, value ->
            val strings = localisedMap.getOrPut(locale(), { mutableMapOf<Key, Localised>() })
            strings.put(key.toString(), value)
            persistence(locale()).write(strings)
        }

    override fun getString(resId: Int): String {
        return localised(resId)
    }

    override fun getString(resId: Int, vararg arguments: Any): String {
        return localised(resId).format(*arguments)
    }

    override fun getQuantityString(resId: Int, quantity: Int, vararg arguments: Any): String {
        // Intentionally no support for quantity strings for now
        return localised(resId).format(*arguments)
    }

    init {
        repo.content.doWhenSet().then {
            "i18n".ktx().v("refreshing locale")
            locale.refresh(force = true)
        }
        locale.doWhenSet().then {
            val strings = localisedMap.getOrPut(locale(), { mutableMapOf<Key, Localised>() })
            strings.putAll(persistence(locale()).read(strings))
            Format.setup(ctx, locale())
        }
    }

}

class I18nPersistence(
        xx: Environment,
        private val locale: LanguageTag
) : PersistenceWithSerialiser<Map<Key, Localised>>(xx) {

    val p by lazy { serialiser("i18n_$locale") }

    override fun read(current: Map<Key, Localised>): Map<Key, Localised> {
        val count = p.getInt("keys", 0)
        val map = IntRange(0, count - 1).map {
            p.getString("k_$it", "") to p.getString("v_$it", "")
        }.filter { it.first.isNotBlank() && it.second.isNotEmpty() }.toMap()
        return if (map.isNotEmpty()) map else current
    }

    override fun write(source: Map<Key, Localised>) {
        val e = p.edit()
        e.putInt("keys", source.size)
        var i = 0
        source.forEach { (k, v) ->
            e.putString("k_$i", k)
            e.putString("v_$i", v)
            i++
        }
        e.apply()
    }

}

fun I18n.getBrandedString(resId: Int): String {
    return getString(resId, getString(R.string.branding_app_name_short))
}
