package ui

import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import core.WebViewActivity.Companion.EXTRA_URL
import core.ktx
import gs.environment.Worker
import gs.property.newProperty
import java.net.URL


class StaticUrlWebActivity : AbstractWebActivity() {

    private val ktx = ktx("StaticUrlWebActivity")
    private val w: Worker by lazy { ktx.di().with("gscore").instance<Worker>() }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        targetUrl = newProperty(w, { URL(intent.getStringExtra(EXTRA_URL)) })
        super.onCreate(savedInstanceState)
    }

}
