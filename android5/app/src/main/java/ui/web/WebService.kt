/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui.web

import android.view.View
import android.view.ViewGroup
import android.webkit.*
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import model.Uri
import org.blokada.R
import service.ContextService
import utils.Logger
import java.lang.ref.WeakReference

object WebService {

    private val log = Logger("Web")
    private val context = ContextService

    private var webView = WeakReference<WebView?>(null)
    private var goingBack = false

    interface Interaction {
        fun onOpenInBrowser(url: String)
        fun onDownload(url: String)
        fun onLoaded(url: String)
        fun onLoadedWithError(url: String, error: String)
        fun onWentBackToTheBeginning()
    }

    fun getWebView(interaction: Interaction): WebView {
        var view = webView.get()
        if (view == null) {
            view = createWebView()
        }

        (view.parent as ViewGroup?)?.removeAllViews()
        goingBack = false
        view.clearHistory() // This does not seem to work
        view.loadUrl("about:blank") // This doesnt help much either. WebView = <3
        setInteraction(view, interaction)
        return view
    }

    fun goBack(): Boolean {
        val view = webView.get()
        return view?.let {
            if (it.canGoBack()) {
                goingBack = true
                it.goBack()
                true
            } else false
        } ?: false
    }

    private fun createWebView(): WebView {
        val web = WebView(context.requireContext())
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        //if (big) web.minimumHeight = ctx.resources.toPx(480)
        //web.settings.userAgentString = blokadaUserAgent(ctx, viewer = false)

        // A "normal" mobile user agent to make some websites load correctly and not assume we are a crawler
        web.settings.userAgentString = "Mozilla/5.0 (Linux; Android 10; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.111 Mobile Safari/537.36."
        web.webChromeClient = WebChromeClient()
        val cookie = CookieManager.getInstance()
        cookie.setAcceptCookie(true)
        cookie.setAcceptThirdPartyCookies(web, true)

        if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK) && isDarkMode()) {
            WebSettingsCompat.setForceDark(web.settings, WebSettingsCompat.FORCE_DARK_ON)
        }

        webView = WeakReference(web)
        return web
    }

    private fun setInteraction(web: WebView, interaction: Interaction) {
        var error: Pair<Uri, String>? = null
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                return when {
                    !url.startsWith("http") -> {
                        interaction.onOpenInBrowser(url)
                        true
                    }
                    url.endsWith(".apk") -> {
                        interaction.onDownload(url)
                        true
                    }
                    else -> {
                        view.loadUrl(url)
                        false
                    }
                }
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?,
                                         err: WebResourceError?) {
                val url = request?.url?.toString() ?: ""
                handleError(url, err?.errorCode ?: 0, err?.description.toString())
            }

            override fun onReceivedError(view: WebView?, errorCode: Int,
                                         description: String?, failingUrl: String?) {
                handleError(failingUrl ?: "", errorCode, description)
            }

            private fun handleError(url: String, code: Int, desc: String?) {
                log.w("Could not load (code $code): $url. Reason: $desc")
                error = url to "$code $desc"
            }

            override fun onPageFinished(view: WebView?, url: String) {
                // We need to do this hack to the make back button navigation work properly
                if (goingBack && url == "about:blank") {
                    interaction.onWentBackToTheBeginning()
                }
            }
        }

        web.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)

                if (newProgress == 100 && web.url != "about:blank") {
                    error?.let { interaction.onLoadedWithError(it.first, it.second) }
                        ?: interaction.onLoaded(web.url ?: "")
                    error = null
                }
            }
        }
    }

    private fun isDarkMode(): Boolean {
        val attr = context.requireContext().theme.obtainStyledAttributes(
            R.style.Theme_Blokada_Default,
            intArrayOf(android.R.attr.windowLightStatusBar)
        )

        val isDarkMode = !attr.getBoolean(0, true)

        attr.recycle();
        return isDarkMode
    }

}
