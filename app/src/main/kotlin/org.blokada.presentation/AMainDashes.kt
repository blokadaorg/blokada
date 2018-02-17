package org.blokada.presentation

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import gs.environment.Journal
import org.blokada.property.State
import org.blokada.framework.IWhen
import org.blokada.framework.di
import org.blokada.R
import org.blokada.ui.app.Dash
import org.blokada.ui.app.UiState
import java.net.URL

val DASH_ID_DONATE = "main_donate"
val DASH_ID_CONTRIBUTE = "main_contribute"
val DASH_ID_BLOG = "main_blog"
val DASH_ID_FAQ = "main_faq"
val DASH_ID_FEEDBACK = "main_feedback"
val DASH_ID_PATRON = "main_patron"
val DASH_ID_PATRON_ABOUT = "main_patron_about"

class DonateDash(val ctx: Context) : Dash(
        DASH_ID_DONATE,
        R.drawable.ic_heart_box,
        ctx.getBrandedString(R.string.main_donate_desc),
        text = ctx.getString(R.string.main_donate_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup,
                false)
        val actor = ADonateActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class ContributeDash(val ctx: Context) : Dash(
        DASH_ID_CONTRIBUTE,
        R.drawable.ic_code_tags,
        ctx.getBrandedString(R.string.main_contribute_desc),
        text = ctx.getString(R.string.main_contribute_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup,
                false)
        val actor = AContributeActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class BlogDash(val ctx: Context) : Dash(
        DASH_ID_BLOG,
        R.drawable.ic_comment_multiple_outline,
        ctx.getBrandedString(R.string.main_blog_desc),
        text = ctx.getString(R.string.main_blog_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup,
                false)
        val actor = ABlogActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class FaqDash(val ctx: Context) : Dash(
        DASH_ID_FAQ,
        R.drawable.ic_help_outline,
        ctx.getString(R.string.main_faq_desc),
        text = ctx.getString(R.string.main_faq_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup,
                false)
        val actor = AFaqActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class FeedbackDash(val ctx: Context) : Dash(
        DASH_ID_FEEDBACK,
        R.drawable.ic_feedback,
        ctx.getBrandedString(R.string.main_feedback_desc),
        text = ctx.getString(R.string.main_feedback_text),
        hasView = true
) {
    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup, false)
        val actor = AFeedbackActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class PatronDash(val ctx: Context, val s: State = ctx.di().instance()) : Dash(
        DASH_ID_PATRON,
        R.drawable.ic_settings,
        text = ctx.getString(R.string.main_patron),
        hasView = true,
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, {
            URL("${s.localised().content}/patron_redirect.html")
        }))
) {
    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup, false)
        val actor = PatronActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class PatronAboutDash(val ctx: Context) : Dash(
        DASH_ID_PATRON_ABOUT,
        R.drawable.ic_settings,
        text = ctx.getString(R.string.main_patron_about),
        hasView = true
) {
    override fun createView(parent: Any): Any? {
        val view = LayoutInflater.from(ctx).inflate(R.layout.content_webview, parent as ViewGroup, false)
        val actor = PatronAboutActor(view)
        onBack = { actor.reload() }
        return view
    }
}

class AutoStartDash(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash(
        "main_autostart",
        icon = false,
        description = ctx.getBrandedString(R.string.main_autostart_desc),
        text = ctx.getString(R.string.main_autostart_text),
        isSwitch = true
) {

    override var checked = false
        set(value) { if (field != value) {
            field = value
            s.startOnBoot %= value
            onUpdate.forEach { it() }
        }}

    private var listener: IWhen? = null
    init {
        listener = s.startOnBoot.doOnUiWhenSet().then {
            checked = s.startOnBoot()
        }
    }
}

class ConnectivityDash(
        val ctx: Context,
        val s: State = ctx.di().instance()
) : Dash(
        "main_connectivity",
        icon = false,
        description = ctx.getBrandedString(R.string.main_connectivity_desc),
        text = ctx.getString(R.string.main_connectivity_text),
        isSwitch = true
) {

    override var checked = false
        set(value) { if (field != value) {
            field = value
            s.watchdogOn %= value
            onUpdate.forEach { it() }
        }}

    private var listener: IWhen? = null
    init {
        listener = s.watchdogOn.doOnUiWhenSet().then {
            checked = s.watchdogOn()
        }
    }
}

class OpenInBrowserDash(
        val ctx: Context,
        val url: () -> URL
) : Dash(
        "open_in_browser",
        R.drawable.ic_open_in_new,
        onClick = { dashRef ->
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.setData(Uri.parse(url().toString()))
            ctx.startActivity(intent)
            true
        }
)
