package g11n

import com.github.michaelbull.result.Err
import com.github.michaelbull.result.mapBoth
import com.github.michaelbull.result.mapError
import core.*
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.net.URL
import java.util.*

internal class TranslationsFetcher(
        val urls: () -> Map<Url, Prefix>,
        val doLoadTranslationStore: () -> Result<TranslationStore> = Persistence.translation.load,
        val doSaveTranslationStore: (TranslationStore) -> Result<Any> = Persistence.translation.save,
        val doValidateCacheForUrl: (TranslationStore, Url) -> Boolean = { store, url ->
            store.get(url) + 86400 * 1000 > System.currentTimeMillis()
        },
        val doFetchTranslations: (Url, Prefix) -> Result<Translations> = { url, prefix ->
            Result.of {
                val translationData = loadGzip(openUrl(URL(url), 10 * 1000))
                val translations = emptyTranslations().toMutableList()
                try {
                    val jsonTranslations = JSONArray(translationData)
                    for (i in 0 until jsonTranslations.length()){
                        val jsonTranslation = jsonTranslations.getJSONObject(i)
                        translations.add("${prefix}_${jsonTranslation.getString("key")}" to jsonTranslation.getString("translation"))
                    }

                } catch (e: JSONException) {
                    v("Json parsing error: " + e.message)
                    v("JSON-data was:$translationData")
                    e(e)
                }
                translations
            }
        },
        val doPutTranslation: (Key, Translation) -> Result<Boolean> = { key, translation ->
            Err(Exception("nowhere to put translations"))
        }
) {

    private var store = TranslationStore()

    @Synchronized fun load(ktx: Kontext) {
        doLoadTranslationStore().mapBoth(
                success = {
                    ktx.v("loaded TranslationStore from persistence", it.cache.size)
//                    ktx.emit(Events.FILTERS_CHANGED, it.cache)
                    store = it
                },
                failure = {
                    ktx.e("failed loading TranslationStore from persistence", it)
                }
        )
    }

    @Synchronized fun save(ktx: Kontext) {
        doSaveTranslationStore(store).mapBoth(
                success = { ktx.v("saved TranslationStore to persistence") },
                failure = { ktx.e("failed saving TranslationStore to persistence", it) }
        )
    }

    @Synchronized fun sync(ktx: Kontext) {
        val invalid = urls().filter { !doValidateCacheForUrl(store, it.key) }
        ktx.v("attempting to fetch ${invalid.size} translation urls")

        var failed = 0
        invalid.map { (url, prefix) -> doFetchTranslations(url, prefix).mapBoth(
                success = {
                    ktx.v("translation fetched", url, it.size)
                    url to it
                },
                failure = { ex ->
                    ktx.e("failed fetching translation", url, ex)
                    ++failed
                    url to emptyTranslations()
                }
        ) }.filter { it.second.isNotEmpty() }.forEach { (url, translations) ->
            store = store.put(url)
            translations.forEach { (key, value) ->
                doPutTranslation(key, value).mapError { ex -> ktx.e("failed putting translation", ex) }
            }
        }

        ktx.v("finished fetching translations; $failed failed")
    }

    @Synchronized fun invalidateCache(ktx: Kontext) {
        ktx.v("invalidating translations cache")
        store = TranslationStore()
    }
}
