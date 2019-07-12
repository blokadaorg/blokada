package core

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import gs.environment.ComponentProvider
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.inject
import gs.presentation.WebDash
import gs.property.Device
import gs.property.IProperty
import gs.property.IWhen
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.launch
import org.acra.ACRA
import org.blokada.R
import tunnel.DnsConfigView
import tunnel.TunnelConfigView
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

class SettingsDash(
        val ctx: Context,
        val d: gs.property.Device = ctx.inject().instance(),
        val t: tunnel.Main = ctx.inject().instance()
) : Dash(
        "main_settings",
        icon = R.drawable.ic_tune,
        text = ctx.getString(R.string.main_settings_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        return createConfigView(parent as ViewGroup)
    }

    private var configView: TunnelConfigView? = null

    private fun createConfigView(parent: ViewGroup): TunnelConfigView {
        val ctx = parent.context
        configView = LayoutInflater.from(ctx).inflate(R.layout.view_tunnel_config, parent, false) as TunnelConfigView
        configView?.onRefreshClick = {
            t.invalidateFilters(ctx.ktx("tunnelDash:config:refresh"))
        }
        configView?.onNewConfig = {
            tunnel.Persistence.config.save(it)
            t.reloadConfig(ctx.ktx("tunnelDash:config:new"), d.onWifi())
        }
        configView?.config = tunnel.Persistence.config.load("tunnelDash:config:load".ktx())
        return configView!!
    }
}

class DnsSettingsDash(
        val ctx: Context,
        val d: gs.property.Device = ctx.inject().instance()
) : Dash(
        "main_settings_dns",
        icon = R.drawable.ic_tune,
        text = ctx.getString(R.string.main_settings_text),
        hasView = true
) {

    override fun createView(parent: Any): Any? {
        return createConfigView(parent as ViewGroup)
    }

    private var configView: DnsConfigView? = null

    private fun createConfigView(parent: ViewGroup): DnsConfigView {
        val ctx = parent.context
        configView = LayoutInflater.from(ctx).inflate(R.layout.view_dns_config, parent, false) as DnsConfigView
        return configView!!
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
            intent.setData(Uri.parse(url().toString()))
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
            intent.setData(Uri.parse(url().toString()))
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
        val f: Filters = xx().instance()
) : Dash(
        DASH_ID_LOG,
        R.drawable.ic_comment_multiple_outline,
        onClick = { dashRef ->
            launch(UI) {
                val r = ACRA.getErrorReporter()
                r.putCustomData("hostsCount", ShareLogDash.getHostsCount().toString())
                r.putCustomData("filtersActiveCount", ShareLogDash.getActiveFiltersCount().toString())
                r.handleException(null)
            }
            true
        }
) {


    companion object {

        suspend fun getHostsCount(): Int {
            val e = "shareLog:getHostsCount".ktx().getMostRecent(tunnel.Events.RULESET_BUILT)
            return if (e == null) -1 else e.first - e.second
        }

        suspend fun getActiveFiltersCount(): Int {
            val e = "shareLog:getActiveFiltersCount".ktx().getMostRecent(tunnel.Events.FILTERS_CHANGED)
            return e?.filter { it.active }?.size ?: -1
        }

    }
}
