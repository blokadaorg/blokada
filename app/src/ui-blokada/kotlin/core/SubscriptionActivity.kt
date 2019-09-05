package core

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.widget.FrameLayout
import android.widget.TextView
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsServiceConnection
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
import tunnel.Persistence
import tunnel.blokadaUserAgent
import tunnel.showSnack
import java.net.URL


class SubscriptionActivity : Activity() {

    private val container by lazy { findViewById<FrameLayout>(R.id.view) }
    private val close by lazy { findViewById<TextView>(R.id.close) }
    private val openBrowser by lazy { findViewById<android.view.View>(R.id.browser) }
    private val ktx = ktx("SubscriptionActivity")
    private val w: Worker by lazy { ktx.di().with("gscore").instance<Worker>() }

    private val subscriptionUrl by lazy {
        val cfg = Persistence.blocka.load(ktx)
        newProperty(w, { URL("https://app.blokada.org/activate/${cfg.accountId}") })
    }

    private val dash by lazy {
        WebDash(LazyKodein(ktx.di), subscriptionUrl, reloadOnError = true,
                javascript = true, forceEmbedded = true, big = true,
                onLoadSpecificUrl = "app.blokada.org/success" to {
                    this@SubscriptionActivity.finish()
                    showSnack(R.string.subscription_success)
                })
    }

    private var view: android.view.View? = null
    private var listener: IWhen? = null
    private var exitedToBrowser = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.subscription_container)


        if (bound || bindChromeTabs()) {
            val url = subscriptionUrl().toExternalForm() + "?user-agent=" + blokadaUserAgent(this, true)
            val builder = CustomTabsIntent.Builder()
            val customTabsIntent = builder.build()

            customTabsIntent.launchUrl(this, Uri.parse(url))
            unbindService(connection)
            finish()
        } else {
            view = dash.createView(this, container)
            listener = subscriptionUrl.doOnUiWhenSet().then {
                view?.run { dash.attach(this) }
            }
            container.addView(view)
            close.setOnClickListener { finish() }
            openBrowser.setOnClickListener {
                try {
                    val intent = Intent(Intent.ACTION_VIEW)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    intent.data = Uri.parse(subscriptionUrl().toString())
                    startActivity(intent)
                    exitedToBrowser = true
                } catch (e: Exception) {}
            }
        }
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

        if (exitedToBrowser) {
            exitedToBrowser = false
            finish()
        }
    }

    override fun onStop() {
        super.onStop()

        async {
            ktx.getMostRecent(BLOCKA_CONFIG)?.run {
                delay(3000)
                ktx.v("check account after coming back to SubscriptionActivity")
                tunnel.checkAccountInfo(ktx, this)
            }
        }
    }

    override fun onBackPressed() {
//        if (!dashboardView.handleBackPressed()) super.onBackPressed()
        super.onBackPressed()
    }

    private val CUSTOM_TAB_PACKAGE_NAME = "com.android.chrome"
    private var bound = false

    var connection: CustomTabsServiceConnection = object : CustomTabsServiceConnection() {
        override fun onCustomTabsServiceConnected(name: ComponentName, client: CustomTabsClient) {
            bound = true
        }

        override fun onServiceDisconnected(name: ComponentName) {
            bound = false
        }
    }
    fun bindChromeTabs() = CustomTabsClient.bindCustomTabsService(this, CUSTOM_TAB_PACKAGE_NAME, connection)

}
