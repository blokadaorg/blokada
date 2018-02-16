package org.blokada.ui.app.android

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.view.View
import android.webkit.*
import org.blokada.R
import java.net.URL

class AWebViewActor(
        private val parent: View,
        private val url: () -> URL,
        private val forceEmbedded: Boolean = false
) {

    private val RELOAD_ERROR_MILLIS = 5 * 1000L

    private val web: WebView
    private val handler: Handler
    private var loaded = false

    init {
        web = parent.findViewById(R.id.web_view) as WebView
        web.visibility = View.INVISIBLE
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        val cookie = CookieManager.getInstance()
        cookie.setAcceptCookie(true)
        if (android.os.Build.VERSION.SDK_INT >= 21) {
            cookie.setAcceptThirdPartyCookies(web, true)
        }

        handler = Handler {
            loaded = true
            web.loadUrl(url().toExternalForm())
            true
        }

        web.setWebViewClient(object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                if (url.contains(url().host) || forceEmbedded) {
                    view.loadUrl(url)
                    return false
                } else {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try { parent.context.startActivity(intent) } catch (e: Exception) {}
                    return true
                }
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?,
                                         error: WebResourceError?) {
                val url = if (Build.VERSION.SDK_INT >= 21) request?.url?.toString() else null
                handleError(url)
            }

            override fun onReceivedError(view: WebView?, errorCode: Int,
                                         description: String?, failingUrl: String?) {
                handleError(failingUrl)
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                web.visibility = View.VISIBLE
                if (!loaded) {
                    web.loadUrl("about:blank")
                    loaded = true
                }
            }
        })

        try {
            handler.sendEmptyMessage(0)
        } catch (e: Exception) {
            handleError(null)
        }
    }

    fun reload() {
        web.loadUrl(url().toExternalForm())
    }

    private fun handleError(url: String?) {
//        try {
//            if (url?.contains(url().host) ?: false) {
//                loaded = false
//                handler.sendEmptyMessageDelayed(0, RELOAD_ERROR_MILLIS)
//            }
//        } catch (e: Exception) {}
    }
}
