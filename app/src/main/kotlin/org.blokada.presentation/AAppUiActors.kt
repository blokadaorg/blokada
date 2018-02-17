package org.blokada.presentation

import android.view.View
import com.github.salomonbrys.kodein.instance
import org.blokada.property.State
import org.blokada.framework.di


class AFeedbackActor(
        private val parent: View
) {

    private val URL = {
//        val s: State = parent.context.di().instance()
//        s.localised().feedback
        java.net.URL("https://goo.gl/forms/5YnfrUT9pdILccKx1")
    }

    private val actor = AWebViewActor(parent, URL, forceEmbedded = true)

    fun reload() {
        actor.reload()
    }
}

class AFaqActor(
        private val parent: View
) {

    private val URL = {
        val s: State = parent.context.di().instance()
        java.net.URL("${s.localised().content}/help.html")
    }

    val actor = AWebViewActor(parent, URL)

    fun reload() {
        actor.reload()
    }
}

class ADonateActor(
        private val parent: View
) {

    private val URL = {
        val s: State = parent.context.di().instance()
        java.net.URL("${s.localised().content}/donate.html")
    }

    val actor = AWebViewActor(parent, URL)

    fun reload() {
        actor.reload()
    }
}

class AContributeActor(
        private val parent: View
) {

    private val URL = {
        val s: State = parent.context.di().instance()
        java.net.URL("${s.localised().content}/contribute.html")
    }

    val actor = AWebViewActor(parent, URL)

    fun reload() {
        actor.reload()
    }
}

class PatronActor(private val parent: View) {
    private val URL = {
        val s: State = parent.context.di().instance()
        java.net.URL("${s.localised().content}/patron_redirect.html")
    }

    val actor = AWebViewActor(parent, URL, forceEmbedded = true)

    fun reload() {
        actor.reload()
    }
}

class PatronAboutActor(private val parent: View) {
    private val URL = {
        val s: State = parent.context.di().instance()
        java.net.URL("${s.localised().content}/patron.html")
    }

    val actor = AWebViewActor(parent, URL)

    fun reload() {
        actor.reload()
    }
}

class ABlogActor(
        private val parent: View
) {

    private val URL = {
        java.net.URL("http://block.blokada.org")
    }

    val actor = AWebViewActor(parent, URL)

    fun reload() {
        actor.reload()
    }
}
