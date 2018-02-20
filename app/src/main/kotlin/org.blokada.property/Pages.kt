package org.blokada.property

import com.github.salomonbrys.kodein.instance
import gs.environment.Environment
import gs.environment.Worker
import gs.property.I18n
import gs.property.IProperty
import gs.property.newProperty
import java.net.URL

abstract class Pages {
    abstract val patron: IProperty<URL>
    abstract val patronAbout: IProperty<URL>
    abstract val donate: IProperty<URL>
    abstract val contribute: IProperty<URL>
    abstract val community: IProperty<URL>
    abstract val help: IProperty<URL>
    abstract val feedback: IProperty<URL>
    abstract val changelog: IProperty<URL>
    abstract val filters: IProperty<URL>
    abstract val filtersStrings: IProperty<URL>
    abstract val chat: IProperty<URL>
}
class PagesImpl (
        w: Worker,
        xx: Environment
) : Pages() {

    val i18n: I18n by xx.instance()

    init {
        i18n.locale.doWhenSet().then {
            val c = i18n.contentUrl()
            patron %= URL("$c/patron_redirect.html")
            patronAbout %= URL("$c/patron.html")
            donate %= URL("$c/donate.html")
            contribute %= URL("$c/contribute.html")
            help %= URL("$c/help.html")
            changelog %= URL("$c/changelog.html")
            filters %= URL("$c/filters.txt")
            filtersStrings %= URL("$c/filters.properties")
        }
    }

    override val patron = newProperty(w, { URL("http://localhost") })
    override val patronAbout = newProperty(w, { URL("http://localhost") })
    override val donate = newProperty(w, { URL("http://localhost") })
    override val contribute = newProperty(w, { URL("http://localhost") })
    override val help = newProperty(w, { URL("http://localhost") })
    override val changelog = newProperty(w, { URL("http://localhost") })
    override val filters = newProperty(w, { URL("http://localhost") })
    override val filtersStrings = newProperty(w, { URL("http://localhost") })

    override val community = newProperty(w, { URL("http://block.blokada.org") })
    override val feedback = newProperty(w, { URL("https://goo.gl/forms/5YnfrUT9pdILccKx1") })
    override val chat = newProperty(w, { URL("http://go.blokada.org/chat") })

}
