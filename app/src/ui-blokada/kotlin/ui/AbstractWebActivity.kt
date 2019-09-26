package ui

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.widget.FrameLayout
import android.widget.TextView
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsServiceConnection
import blocka.blokadaUserAgent
import com.github.salomonbrys.kodein.LazyKodein
import core.ktx
import core.modalManager
import gs.presentation.WebDash
import gs.property.IProperty
import gs.property.IWhen
import org.blokada.R
import java.net.URL

abstract class AbstractWebActivity : Activity() {

    private val container by lazy { findViewById<FrameLayout>(R.id.view) }
    private val close by lazy { findViewById<TextView>(R.id.close) }
    private val openBrowser by lazy { findViewById<android.view.View>(R.id.browser) }
    private val ktx = ktx("AbstractWebActivity")

    lateinit var targetUrl: IProperty<URL>

    private val dash by lazy {
        WebDash(LazyKodein(ktx.di), targetUrl, reloadOnError = true,
                javascript = true, forceEmbedded = true, big = true)
    }

    private var view: android.view.View? = null
    private var listener: IWhen? = null
    private var exitedToBrowser = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.subscription_container)

        if (bound || bindChromeTabs()) {
            val url = targetUrl().toExternalForm() + "?user-agent=" + blokadaUserAgent(this, true)
            val builder = CustomTabsIntent.Builder()
            val customTabsIntent = builder.build()

            customTabsIntent.launchUrl(this, Uri.parse(url))
            unbindService(connection)
            finish()
        } else {
            view = dash.createView(this, container)
            listener = targetUrl.doOnUiWhenSet().then {
                view?.run { dash.attach(this) }
            }
            container.addView(view)
            close.setOnClickListener { finish() }
            openBrowser.setOnClickListener {
                try {
                    val intent = Intent(Intent.ACTION_VIEW)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    intent.data = Uri.parse(targetUrl().toString())
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
        targetUrl.cancel(listener)
        modalManager.closeModal()
    }

    override fun onStart() {
        super.onStart()

        if (exitedToBrowser) {
            exitedToBrowser = false
            finish()
        }
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

//    fun bindChromeTabs() = CustomTabsClient.bindCustomTabsService(this, CUSTOM_TAB_PACKAGE_NAME, connection)
    fun bindChromeTabs() = false
}
