package core

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import gs.environment.*
import gs.presentation.WebDash
import gs.property.Device
import gs.property.IProperty
import gs.property.IWhen
import org.acra.ACRA
import org.blokada.R
import java.net.URL

val DASH_ID_DONATE = "main_donate"
val DASH_ID_CONTRIBUTE = "main_contribute"
val DASH_ID_BLOG = "main_blog"
val DASH_ID_FAQ = "main_faq"
val DASH_ID_FEEDBACK = "main_feedback"
val DASH_ID_PATRON = "main_patron"
val DASH_ID_PATRON_ABOUT = "main_patron_about"
val DASH_ID_CTA = "main_cta"
val DASH_ID_CHANGELOG = "main_changelog"
val DASH_ID_CREDITS = "main_credits"

class DonateDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_DONATE,
        R.drawable.ic_heart_box,
        text = ctx.getString(R.string.main_donate_text),
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, pages.donate)),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.donate, javascript = true)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.reload() }
        return view
    }
}

class NewsDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_BLOG,
        R.drawable.ic_earth,
        text = ctx.getString(R.string.main_blog_text),
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, pages.news)),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.news, forceEmbedded = true, javascript = true)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.reload() }
        return view
    }
}

class FaqDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_FAQ,
        R.drawable.ic_help_outline,
        text = ctx.getString(R.string.main_faq_text),
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, pages.help)),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.help)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.reload() }
        return view
    }
}

class FeedbackDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_FEEDBACK,
        R.drawable.ic_feedback,
        text = ctx.getString(R.string.main_feedback_text),
        menuDashes = Triple(null, ChatDash(ctx, pages.chat), OpenInBrowserDash(ctx, pages.feedback)),
        hasView = true
) {
    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.feedback, forceEmbedded = true, javascript = true)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.detach(view) }
        return view
    }
}

class PatronDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_PATRON,
        R.drawable.ic_info,
        text = ctx.getString(R.string.main_patron),
        hasView = true,
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, pages.patron))
) {
    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.patron, forceEmbedded = true, javascript = true, reloadOnError = false)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.reload() }
        return view
    }
}

class PatronAboutDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_PATRON_ABOUT,
        R.drawable.ic_info,
        text = ctx.getString(R.string.main_patron_about),
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, pages.patronAbout)),
        hasView = true
) {
    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.patronAbout, forceEmbedded = true, javascript = true)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.reload() }
        return view
    }
}

class CtaDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_CTA,
        R.drawable.ic_info,
        text = ctx.getString(R.string.main_cta),
        hasView = true,
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, pages.cta))
) {
    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.cta, forceEmbedded = true, javascript = true)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.reload() }
        return view
    }
}

class ChangelogDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_CHANGELOG,
        R.drawable.ic_info,
        text = ctx.getString(R.string.main_changelog),
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, pages.changelog)),
        hasView = true
) {
    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.changelog)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.reload() }
        return view
    }
}

class CreditsDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val pages: Pages = xx().instance()
) : Dash(
        DASH_ID_CREDITS,
        R.drawable.ic_info,
        text = ctx.getString(R.string.main_credits),
        menuDashes = Triple(null, null, OpenInBrowserDash(ctx, pages.credits)),
        hasView = true
) {
    override fun createView(parent: Any): Any? {
        val actor = WebDash(xx, pages.credits)
        val view = actor.createView(ctx, parent as ViewGroup)
        actor.attach(view)
        onBack = { actor.reload() }
        return view
    }
}

class AutoStartDash(
        val ctx: Context,
        val s: Tunnel = ctx.inject().instance()
) : Dash(
        "main_autostart",
        icon = false,
        text = ctx.getString(R.string.main_autostart_text),
        isSwitch = true
) {

    override var checked = false
        set(value) {
            if (field != value) {
                field = value
                s.startOnBoot %= value
                onUpdate.forEach { it() }
            }
        }

    private var listener: IWhen? = null

    init {
        listener = s.startOnBoot.doOnUiWhenSet().then {
            checked = s.startOnBoot()
        }
    }
}

class ConnectivityDash(
        val ctx: Context,
        val s: Device = ctx.inject().instance()
) : Dash(
        "main_connectivity",
        icon = false,
        text = ctx.getString(R.string.main_connectivity_text),
        isSwitch = true
) {

    override var checked = false
        set(value) {
            if (field != value) {
                field = value
                s.watchdogOn %= value
                onUpdate.forEach { it() }
            }
        }

    private var listener: IWhen? = null

    init {
        listener = s.watchdogOn.doOnUiWhenSet().then {
            checked = s.watchdogOn()
        }
    }
}

class OpenInBrowserDash(
        val ctx: Context,
        val url: IProperty<URL>
) : Dash(
        "open_in_browser",
        R.drawable.ic_open_in_new,
        onClick = { dashRef ->
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.data = Uri.parse(url().toString())
            ctx.startActivity(intent)
            true
        }
)

class ChatDash(
        val ctx: Context,
        val url: IProperty<URL>
) : Dash(
        "chat",
        R.drawable.ic_comment_multiple_outline,
        onClick = { dashRef ->
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.data = Uri.parse(url().toString())
            ctx.startActivity(intent)
            true
        }
)

val DASH_ID_LOG = "share_log"

class ShareLogDash(
        val xx: Environment,
        val ctx: Context = xx().instance(),
        val activity: ComponentProvider<Activity> = xx().instance(),
        val j: Journal = xx().instance(),
        val s: Device = xx().instance(),
        val k: KeepAlive = xx().instance(),
        val f: Filters = xx().instance(),
        val cmd: Commands = xx().instance(),
        val time: Time = xx().instance()
) : Dash(
        DASH_ID_LOG,
        R.drawable.ic_comment_multiple_outline,
        onClick = { dashRef ->
            val r = ACRA.getErrorReporter()
            r.putCustomData("hostsCount", "${cmd.one(MonitorHostsCount())}")
            r.putCustomData("filtersActiveCount", "${cmd.one(MonitorFilters()).filter { it.active }.size}")
            r.handleException(null)
            true
        }
)
