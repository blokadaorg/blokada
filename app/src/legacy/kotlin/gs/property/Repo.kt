package gs.property

import com.github.salomonbrys.kodein.instance
import core.ktx
import core.loadGzip
import core.openUrl
import gs.environment.Environment
import gs.environment.Time
import gs.environment.Worker
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
        val fetchTimeout = 10 * 10000

        try {
            val repo = loadGzip(openUrl(repoURL, fetchTimeout))
            val locales = repo[1].split(" ").map {
                // Because Java APIs suck
                val parts = it.split("_")
                when(parts.size) {
                    3 -> Locale(parts[0], parts[1], parts[2])
                    2 -> Locale(parts[0], parts[1])
                    else -> Locale(parts[0])
                }
            }
            ktx.v("repo downloaded")

            lastRefreshMillis %= time.now()
            RepoContent(
                    contentPath = URL(repo[0]),
                    locales = locales,
                    newestVersionCode = repo[2].toInt(),
                    newestVersionName = repo[3],
                    downloadLinks = repo.subList(4, repo.size).map { URL(it) },
                    fetchedUrl = url()
            )
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

