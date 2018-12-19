package gs.presentation

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.*
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import core.ListSection
import core.Scrollable
import core.SlotVB
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.LazyProvider
import gs.property.IProperty
import gs.property.IWhen
import org.blokada.R
import java.net.URL

class WebDash(
        private val xx: Environment,
        private val url: IProperty<URL>,
        private val forceEmbedded: Boolean = false,
        private var reloadOnError: Boolean = false,
        private val javascript: Boolean = false,
        private val big: Boolean = false,
        private val j: Journal = xx().instance(),
        private val provider: LazyProvider<View> = xx().with("webview").instance(),
        private val small: Boolean = false,
        private val onLoadSpecificUrl: Pair<String, () -> Unit>? = null
): CallbackViewBinder, Scrollable, ListSection {

    override val viewType = 43

    override fun getScrollableView() = webView!!

    override fun setOnScroll(onScrollDown: () -> Unit, onScrollUp: () -> Unit, onScrollStopped: () -> Unit) {
    }

    override fun setOnSelected(listener: (item: SlotVB?) -> Unit) = Unit

    override fun scrollToSelected() = Unit

    override fun selectNext() {
        webView?.scrollBy(0, 100)
    }

    override fun selectPrevious() {
        webView?.scrollBy(0, -100)
    }

    override fun unselect() = Unit

    override fun createView(ctx: Context, parent: ViewGroup): View {
        var v = provider.get()
        if (v == null) {
            // TODO: Dont use inflater
            val themedContext = ContextThemeWrapper(ctx, R.style.GsTheme_Dialog)
            // TODO: one instance for all
            v = LayoutInflater.from(themedContext).inflate(
                    if (small) R.layout.webview_small
                    else if (big) R.layout.webview_big
                    else R.layout.webview
                    , parent, false)
//            provider.set(v)
        }
        return v!!
    }

    private var attached: () -> Unit = {}
    private var detached: () -> Unit = {}

    override fun onAttached(attached: () -> Unit) {
        this.attached = attached
    }

    override fun onDetached(detached: () -> Unit) {
        this.detached = detached
    }

    private val RELOAD_ERROR_MILLIS = 5 * 1000L

    private var webView: WebView? = null
    private var urlChanged: IWhen? = null
    private var clean = false
    private var reloadCounter = 0

    private val loader = Handler {
        val v = webView
        clean = true
        reloadCounter++
        if (v == null) clean = false
        else {
            val u = url().toExternalForm()
            j.log("WebDash: load: $u")
            v.loadUrl(u)
        }
        true
    }

    override fun attach(view: View) {
        val ctx = view.context
        val web = view.findViewById(R.id.web_view) as WebView
        webView = web

        web.visibility = View.INVISIBLE
        if (javascript) web.settings.javaScriptEnabled = true
        if (big) web.minimumHeight = ctx.resources.toPx(480)
        web.settings.domStorageEnabled = true
        val cookie = CookieManager.getInstance()
        cookie.setAcceptCookie(true)
        if (Build.VERSION.SDK_INT >= 21) cookie.setAcceptThirdPartyCookies(web, true)

        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                if (onLoadSpecificUrl != null && url.contains(onLoadSpecificUrl.first)) {
                    onLoadSpecificUrl.second()
                    return true
                } else if (forceEmbedded || url.contains(url().host)) {
                    view.loadUrl(url)
                    return false
                } else {
                    // Open external urls in browser
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        ctx.startActivity(intent)
                    } catch (e: Exception) {
                        j.log("WebDash: failed to open external url", e)
                    }
                    return true
                }
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?,
                                         error: WebResourceError?) {
                val url = if (Build.VERSION.SDK_INT >= 21) request?.url?.toString() else null
                if (Build.VERSION.SDK_INT >= 23) handleError(url, Exception("onReceivedError: ${error?.errorCode} ${error?.description}"))
                else handleError(url, Exception("onReceivedError: $error"))
            }

            override fun onReceivedError(view: WebView?, errorCode: Int,
                                         description: String?, failingUrl: String?) {
                handleError(failingUrl, Exception("onReceivedError2 $errorCode $description"))
            }

            override fun onPageFinished(view: WebView?, url2: String?) {
                if (clean) {
                    web.visibility = android.view.View.VISIBLE
                    attached()
                }
            }
        }

        urlChanged = url.doOnUiWhenChanged().then { reload() }
        load()
    }

    private fun load() {
        try { loader.sendEmptyMessage(0) } catch (e: Exception) { handleError(null, e) }
    }

    fun reload() {
        reloadCounter = 0
        load()
    }

    private fun handleError(url: String?, reason: Exception) {
        try {
            j.log("WebDash: load failed: $url", reason)
            clean = false
            if (!reloadOnError) return
            if (reloadCounter++ <= 10) loader.sendEmptyMessageDelayed(0, RELOAD_ERROR_MILLIS)
        } catch (e: Exception) {}
    }

    override fun detach(view: View) {
        (view.parent as ViewGroup?)?.removeView(view)
        webView = null
        url.cancel(urlChanged)
        urlChanged = null
        clean = false
        reloadCounter = 0
        detached()
        detached = {}
        attached = {}
    }

}
