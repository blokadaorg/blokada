package core

import android.app.Activity
import android.widget.FrameLayout
import android.widget.Toast
import com.github.salomonbrys.kodein.LazyKodein
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import gs.environment.Worker
import gs.presentation.WebDash
import gs.property.newProperty
import kotlinx.coroutines.experimental.async
import org.blokada.R
import tunnel.BLOCKA_CONFIG
import tunnel.BlockaConfig
import java.net.URL


class SubscriptionActivity : Activity() {

    private val container by lazy { findViewById<FrameLayout>(R.id.view) }
    private val ktx = ktx("SubscriptionActivity")
    private val w: Worker by lazy { ktx.di().with("gscore").instance<Worker>() }

    private val subscriptionUrl by lazy { newProperty(w, { URL("http://localhost") }) }
    private val updateUrl = { cfg: BlockaConfig ->
        subscriptionUrl %= URL("https://vpn.blocka.net/#/activate/${cfg.accountId}")
    }

    private val dash by lazy {
        WebDash(LazyKodein(ktx.di), subscriptionUrl, reloadOnError = false,
                javascript = true, forceEmbedded = true, big = true,
                onLoadSpecificUrl = "vpn.blocka.net/#/success" to {
                    this@SubscriptionActivity.finish()
                    Toast.makeText(this@SubscriptionActivity, R.string.subscription_success,
                            Toast.LENGTH_LONG).show()
                })
    }

    private var view: android.view.View? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.subscription_container)

        view = dash.createView(this, container)
        view?.run { dash.attach(this) }
        container.addView(view)
    }

    override fun onDestroy() {
        super.onDestroy()
        view?.run { dash.detach(this) }
        container.removeAllViews()
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
                tunnel.checkAccountInfo(ktx, this)
            }
        }
    }

    override fun onBackPressed() {
//        if (!dashboardView.handleBackPressed()) super.onBackPressed()
        super.onBackPressed()
    }

}
