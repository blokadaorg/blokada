package gs.property

import com.github.salomonbrys.kodein.instance
import core.*
import gs.environment.Environment
import gs.environment.Time
import gs.environment.Worker
import org.json.JSONException
import org.json.JSONObject
import java.net.URL
import java.util.*

data class RepoContent(
        val contentPath: URL?,
        val locales: List<Locale>,
        val newestVersionCode: Int,
        val newestVersionName: String,
        val downloadLinks: List<URL>,
        internal val fetchedUrl: String
)

abstract class Repo {
    abstract val url: IProperty<String>
    abstract val content: IProperty<RepoContent>
    abstract val lastRefreshMillis: IProperty<Long>
}

class RepoImpl(
        private val kctx: Worker,
        private val xx: Environment
) : Repo() {

    private val time: Time by xx.instance()
    private val version: Version by xx.instance()

    override val url = newPersistedProperty(kctx, BasicPersistence(xx, "repo_url"), zeroValue = { "" })

    init {
        url.doWhenSet().then {
            "repo:url".ktx().v("url set", url())
            content.refresh(force = true)
        }
    }

    override val lastRefreshMillis = newPersistedProperty(kctx, BasicPersistence(xx, "repo_refresh"), zeroValue = { 0L })

    private val repoRefresh = {
        val ktx = "repo:refresh".ktx()
        ktx.v("repo refresh start")
        val repoURL = java.net.URL(url())
        val fetchTimeout = 10 * 1000

        try {
            ktx.v("repo downloaded")
            val repoData = loadGzip(openUrl(repoURL, fetchTimeout))
            try {

                //val jsonRepo = JSONObject(repoData)
                //REMOVE!!!!!!!!!!!!!!!!
                val jsonRepo = JSONObject("{\"contentPath\":\"https://blokada.org/api/v4/content\",\"locales\":[\"en\",\"pl_PL\",\"hu_HU\",\"ru_RU\",\"es_ES\",\"hi_IN\",\"tr_TR\",\"fr_FR\",\"ms_MY\",\"uk_UA\",\"de_DE\",\"cs_CZ\",\"it_IT\",\"pt_BR\",\"nb_NO\",\"zh_TW\",\"id_ID\",\"zh_CN\",\"bg_BG\",\"lv_LV\",\"ca_ES\",\"pt_PT\",\"ar_SA\",\"sk_SK\",\"iw_IL\",\"zu_Z\"],\"newestVersionCode\":404000002,\"newestVersionName\":\"4.4.2\",\"downloadLinks\":[\"https://github.com/blokadaorg/blokada/releases/download/4.4.2/blokada-v4.4.2.apk\",\"https://bitbucket.org/blokada/blokada/downloads/blokada-v4.4.2.apk\"]}")

                lastRefreshMillis %= time.now()

                val jsonLocales = jsonRepo.getJSONArray("locales")
                val locales = emptyList<Locale>().toMutableList()
                for (i in 0 until jsonLocales.length()){
                    val parts = jsonLocales.getString(i).split("_")
                    locales.add(
                        when(parts.size) {
                            3 -> Locale(parts[0], parts[1], parts[2])
                            2 -> Locale(parts[0], parts[1])
                            else -> Locale(parts[0])
                        }
                    )
                }
                val jsonDownloadLinks = jsonRepo.getJSONArray("downloadLinks")
                val downloadLinks = emptyList<URL>().toMutableList()
                for (i in 0 until jsonDownloadLinks.length()){
                    downloadLinks.add(URL(jsonDownloadLinks.getString(i)))
                }

                RepoContent(
                        contentPath = URL(jsonRepo.getString("contentPath")),
                        locales = locales,
                        newestVersionCode = jsonRepo.getLong("newestVersionCode").toInt(),
                        newestVersionName = jsonRepo.getString("newestVersionName"),
                        downloadLinks = downloadLinks,
                        fetchedUrl = url()
                )
            } catch (e: JSONException) {
                v("Json parsing error: " + e.message)
                v("JSON-data was:$repoData")
                throw e
            }
        } catch (e: Exception) {
            ktx.e("repo refresh fail", e)
            if (e is java.io.FileNotFoundException) {
                ktx.w("app version is obsolete", e)
                version.obsolete %= true
            }
            throw e
        }
    }

    override val content = newPersistedProperty(kctx, ARepoPersistence(xx),
            zeroValue = { RepoContent(null, listOf(), 0, "", listOf(), "") },
            refresh = { repoRefresh() },
            shouldRefresh = {
                val ttl = 86400 * 1000

                when {
                    it.fetchedUrl != url() -> true
                    lastRefreshMillis() + ttl < time.now() -> true
                    it.downloadLinks.isEmpty() -> true
                    it.contentPath == null -> true
                    it.locales.isEmpty() -> true
                    else -> false
                }
            }
    )
}

class ARepoPersistence(xx: Environment) : PersistenceWithSerialiser<RepoContent>(xx) {

    val p by lazy { serialiser("repo") }

    override fun read(current: RepoContent): RepoContent {
        return try {
            RepoContent(
                    contentPath = URL(p.getString("contentPath", "")),
                    locales = p.getStringSet("locales", setOf()).map { Locale(it) }.toList(),
                    newestVersionCode = p.getInt("code", 0),
                    newestVersionName = p.getString("name", ""),
                    downloadLinks = p.getStringSet("links", setOf()).map { URL(it) }.toList(),
                    fetchedUrl = p.getString("fetchedUrl", "")
            )
        } catch (e: Exception) {
            current
        }
    }

    override fun write(source: RepoContent) {
        val e = p.edit()
        e.putString("contentPath", source.contentPath.toString())
        e.putStringSet("locales", source.locales.map { it.toString() }.toSet())
        e.putInt("code", source.newestVersionCode)
        e.putString("name", source.newestVersionName)
        e.putStringSet("links", source.downloadLinks.map { it.toString() }.toSet())
        e.putString("fetchedUrl", source.fetchedUrl)
        e.apply()
    }

}

