package g11n

import core.Time
import core.Url

typealias Prefix = String
typealias Key = String
typealias Translation = String
typealias Translations = List<Pair<Key, Translation>>

fun emptyTranslations() = emptyList<Pair<Key, Translation>>()

data class TranslationStore(
        val cache: Map<Url, Time> = emptyMap()
) {
    fun get(url: Url) = cache.getOrElse(url, { 0 })
    fun put(url: Url) = TranslationStore(cache.plus(url to System.currentTimeMillis()))
}
