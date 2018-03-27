package core

import android.content.Context
import com.github.salomonbrys.kodein.*
import gs.environment.Environment
import gs.environment.Worker
import gs.property.I18n
import gs.property.IProperty
import gs.property.newProperty
import java.net.HttpURLConnection
import java.net.URL

abstract class Pages {
    abstract val patron: IProperty<URL>
    abstract val patronAbout: IProperty<URL>
    abstract val cta: IProperty<URL>
    abstract val donate: IProperty<URL>
    abstract val news: IProperty<URL>
    abstract val help: IProperty<URL>
    abstract val feedback: IProperty<URL>
    abstract val changelog: IProperty<URL>
    abstract val credits: IProperty<URL>
    abstract val filters: IProperty<URL>
    abstract val filtersStrings: IProperty<URL>
    abstract val chat: IProperty<URL>
    abstract val dns: IProperty<URL>
    abstract val dnsStrings: IProperty<URL>
}
class PagesImpl (
        w: Worker,
        xx: Environment
) : Pages() {

    val i18n: I18n by xx.instance()

    init {
        i18n.locale.doWhenSet().then {
            val c = i18n.contentUrl()
            patronAbout %= URL("$c/patron.html")
            cta %= URL("$c/cta.html")
            donate %= URL("$c/donate.html")
            help %= URL("$c/help.html")
            changelog %= URL("$c/changelog.html")
            credits %= URL("$c/credits.html")
            filters %= URL("$c/filters.txt")
            filtersStrings %= URL("$c/filters.properties")
            dns %= URL("$c/dns.txt")
            dnsStrings %= URL("$c/dns.properties")

            patron %= resolveRedirect(patron())
        }
    }

    override val patronAbout = newProperty(w, { URL("http://localhost") })
    override val cta = newProperty(w, { URL("http://localhost") })
    override val donate = newProperty(w, { URL("http://localhost") })
    override val help = newProperty(w, { URL("http://localhost") })
    override val changelog = newProperty(w, { URL("http://localhost") })
    override val credits = newProperty(w, { URL("http://localhost") })
    override val filters = newProperty(w, { URL("http://localhost") })
    override val filtersStrings = newProperty(w, { URL("http://localhost") })
    override val dns = newProperty(w, { URL("http://localhost") })
    override val dnsStrings = newProperty(w, { URL("http://localhost") })

    override val news = newProperty(w, { URL("http://go.blokada.org/news") })
    override val feedback = newProperty(w, { URL("http://go.blokada.org/feedback") })
    override val chat = newProperty(w, { URL("http://go.blokada.org/chat") })
    override val patron = newProperty(w, { URL("http://go.blokada.org/patron_redirect") })

}

fun newPagesModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Pages>() with singleton {
            PagesImpl(with("gscore").instance(), lazy)
        }
    }
}
private fun resolveRedirect(url: URL): URL {
    return try {
        val ucon = url.openConnection() as HttpURLConnection
        ucon.setInstanceFollowRedirects(false)
        URL(ucon.getHeaderField("Location"))
    } catch (e: Exception) {
        url
    }
}
