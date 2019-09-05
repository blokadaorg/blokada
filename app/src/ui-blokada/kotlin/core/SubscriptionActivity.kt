package core

import android.app.Activity
import android.widget.FrameLayout
import android.widget.ImageView
import com.github.salomonbrys.kodein.LazyKodein
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import gs.environment.Worker
import gs.presentation.WebDash
import gs.property.IWhen
import gs.property.newProperty
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.delay
import org.blokada.R
import tunnel.BLOCKA_CONFIG
import tunnel.BlockaConfig
import tunnel.showSnack
import java.net.URL


class SubscriptionActivity : Activity() {

    private val container by lazy { findViewById<FrameLayout>(R.id.view) }
    private val close by lazy { findViewById<ImageView>(R.id.close) }
    private val ktx = ktx("SubscriptionActivity")
    private val w: Worker by lazy { ktx.di().with("gscore").instance<Worker>() }

    private val subscriptionUrl by lazy { newProperty(w, { URL("https://localhost") }) }
    private val updateUrl = { cfg: BlockaConfig ->
        subscriptionUrl %= URL("https://app.blokada.org/#/activate/${cfg.accountId}")
    }

    private val dash by lazy {
        WebDash(LazyKodein(ktx.di), subscriptionUrl, reloadOnError = true,
                javascript = true, forceEmbedded = true, big = true,
                onLoadSpecificUrl = "app.blokada.org/#/success" to {
                    this@SubscriptionActivity.finish()
                    showSnack(R.string.subscription_success)
                })
    }

    private var view: android.view.View? = null
    private var listener: IWhen? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.subscription_container)

        view = dash.createView(this, container)
        listener = subscriptionUrl.doOnUiWhenChanged().then {
            view?.run { dash.attach(this) }
        }
        container.addView(view)
        close.setOnClickListener { finish() }
    }

    override fun onDestroy() {
        super.onDestroy()
        view?.run { dash.detach(this) }
        container.removeAllViews()
        subscriptionUrl.cancel(listener)
        modalManager.closeModal()
    }

    override fun onStart() {
        super.onStart()
        ktx.on(BLOCKA_CONFIG, updateUrl)
    }

    override fun onStop() {
        super.onStop()
        ktx.cancel(BLOCKA_CONFIG, updateUrl)

        async {
            ktx.getMostRecent(BLOCKA_CONFIG)?.run {
                delay(3000)
                tunnel.checkAccountInfo(ktx, this)
            }
        }
    }

    override fun onBackPressed() {
//        if (!dashboardView.handleBackPressed()) super.onBackPressed()
        super.onBackPressed()
    }

}
