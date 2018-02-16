package org.blokada.ui.app.android

import android.view.View
import com.github.salomonbrys.kodein.instance
import org.blokada.app.State
import org.blokada.framework.android.di


class ABugActor(
        private val parent: View
) {

    private val URL = {
        val s: State = parent.context.di().instance()
        s.localised().bug
    }

    private val actor = AWebViewActor(parent, URL, forceEmbedded = true)

    fun reload() {
        actor.reload()
    }

}

class AFeedbackActor(
        private val parent: View
) {

    private val URL = {
        val s: State = parent.context.di().instance()
        s.localised().feedback
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
