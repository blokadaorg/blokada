package org.blokada.property

import gs.environment.Environment
import gs.environment.Worker
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
}
class PagesImpl (
        w: Worker,
        xx: Environment
) : Pages() {

    override val patron = newProperty(w, { URL("http://localhost") })
    override val patronAbout = newProperty(w, { URL("http://localhost") })
    override val donate = newProperty(w, { URL("http://localhost") })
    override val contribute = newProperty(w, { URL("http://localhost") })
    override val community = newProperty(w, { URL("http://localhost") })
    override val help = newProperty(w, { URL("http://localhost") })
    override val feedback = newProperty(w, { URL("http://localhost") })
    override val changelog = newProperty(w, { URL("http://localhost") })

}
