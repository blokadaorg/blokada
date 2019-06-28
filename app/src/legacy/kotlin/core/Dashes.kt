package core

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.format.DateUtils
import android.view.View
import android.view.ViewGroup
import com.github.salomonbrys.kodein.LazyKodein
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import filter.AFilterListView
import gs.environment.Worker
import gs.presentation.LayoutViewBinder
import gs.presentation.ViewBinder
import gs.presentation.ViewTypeGenerator
import gs.presentation.WebDash
import gs.property.*
import org.blokada.R
import tunnel.Filter
import tunnel.TunnelConfigView
import tunnel.showSnack
import update.AUpdateView
import update.UpdateCoordinator
import update.isUpdate
import kotlin.math.max

class BlockedDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.dash_top) {

    private val t by lazy { ktx.di().instance<Tunnel>() }

    private var updateCount: IWhen? = null

    override fun attach(view: View) {
        view as DashTopView
        view.small = "blocked"
        updateCount = t.tunnelDropCount.doOnUiWhenSet().then {
            view.big = Format.counter(t.tunnelDropCount())
        }
    }

    override fun detach(view: View) {
        t.tunnelDropCount.cancel(updateCount)
    }

}

class HostsDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.dash_top) {

    private var rulesetBuilt = { event: Pair<Int, Int> -> }
    private var rulesetBuilding = {}
    private var filtersChanging = {}

    override fun attach(view: View) {
        view as DashTopView

        rulesetBuilt = { event: Pair<Int, Int> ->
            val (deny, allow) = event
            view.big = Format.counter(max(deny - allow, 0))
            view.small = "hosts"
        }

        rulesetBuilding = {
//            view.big = "-"
            view.small = ktx.ctx.getString(R.string.tunnel_hosts_updating)
        }

        filtersChanging = {
//            view.big = "-"
            view.small = ktx.ctx.getString(R.string.tunnel_hosts_downloading)
        }

        ktx.on(tunnel.Events.RULESET_BUILT, rulesetBuilt)
        ktx.on(tunnel.Events.RULESET_BUILDING, rulesetBuilding)
        ktx.on(tunnel.Events.FILTERS_CHANGING, filtersChanging)
    }

    override fun detach(view: View) {
        ktx.cancel(tunnel.Events.RULESET_BUILT, rulesetBuilt)
        ktx.cancel(tunnel.Events.RULESET_BUILDING, rulesetBuilding)
        ktx.cancel(tunnel.Events.FILTERS_CHANGING, filtersChanging)
    }

}

class AppsDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.dash_top) {

    private var filtersChanged = { event: Collection<Filter> -> }

    override fun attach(view: View) {
        view as DashTopView

        filtersChanged = { event: Collection<Filter> ->
            val count = event.filter { it.active && it.whitelist }.size
            view.big = "%d apps".format(count)
            view.small = "in whitelist"
        }

        ktx.on(tunnel.Events.FILTERS_CHANGED, filtersChanged)
    }

    override fun detach(view: View) {
        ktx.cancel(tunnel.Events.FILTERS_CHANGED, filtersChanged)
    }

}

class DnsDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.dash_top) {

    private val dns by lazy { ktx.di().instance<Dns>() }
    private val i18n by lazy { ktx.di().instance<I18n>() }
    private var updateText: IWhen? = null

    override fun attach(view: View) {
        view as DashTopView

        updateText = dns.choices.doOnUiWhenSet().then {
            val choice = dns.choices().firstOrNull { it.active }
            view.big = when {
                choice == null -> ktx.ctx.getString(R.string.dns_text_none)
                choice.servers.isEmpty() -> ktx.ctx.getString(R.string.dns_text_none)
                choice.id.startsWith("custom") -> printServers(choice.servers)
                else -> i18n.localisedOrNull("dns_${choice.id}_name") ?: choice.id.capitalize()
            }
            view.small = "active"
        }
    }

    override fun detach(view: View) {
        dns.choices.cancel(updateText)
    }

}

class UpdateDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.dash_top) {

    private val repo by lazy { ktx.di().instance<Repo>() }
    private var updateText: IWhen? = null

    override fun attach(view: View) {
        view as DashTopView

        updateText = repo.content.doOnUiWhenSet().then {
            if (isUpdate(ktx.ctx, repo.content().newestVersionCode)) {
                view.big = ktx.ctx.getString(R.string.update_dash_available)
                view.small = repo.content().newestVersionName
            } else {
                view.big = ktx.ctx.getString(R.string.update_dash_uptodate)
                view.small = DateUtils.getRelativeTimeSpanString(repo.lastRefreshMillis()).toString()
            }
        }
    }

    override fun detach(view: View) {
        repo.content.cancel(updateText)
    }

}

class WhitelistDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.view_customlist) {

    override fun attach(view: View) {
        view as AFilterListView
        view.whitelist = true
    }

    override fun detach(view: View) {

    }

}

class AdsDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.dash_ads), Backable, Scrollable {

    private var view: DashAdsView? = null

    override fun attach(view: View) {
        this.view = view as DashAdsView
    }

    override fun detach(view: View) {
        this.view = null
    }

    override fun handleBackPressed(): Boolean {
        return view?.handleBackPressed() ?: false
    }

    override fun setOnScroll(onScrollDown: () -> Unit, onScrollUp: () -> Unit, onScrollStopped: () -> Unit) {
        view?.setOnScroll(onScrollDown, onScrollUp, onScrollStopped)
    }

    override fun getScrollableView() = view!!.getScrollableView()
}

class DnsMainDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.view_dnslist) {

    override fun attach(view: View) {
    }

    override fun detach(view: View) {

    }

}

class SettingsMainDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.view_tunnel_config) {

    private val t by lazy { ktx.di().instance<tunnel.Main>() }
    private val d by lazy { ktx.di().instance<Device>() }

    override fun attach(view: View) {
        view as TunnelConfigView
        view.onRefreshClick = {
            t.invalidateFilters(ktx)
        }
        view.onNewConfig = {
            tunnel.Persistence.config.save(it)
            t.reloadConfig(ktx, d.onWifi())
        }
        view.config = tunnel.Persistence.config.load(ktx)
    }

    override fun detach(view: View) {
        view as TunnelConfigView
        view.onRefreshClick = {}
        view.onNewConfig = {}
    }

}

class UpdatesDash(private val ktx: AndroidKontext): LayoutViewBinder(R.layout.view_update) {

    private var next: Int = 0
    private val updater by lazy { ktx.di().instance<UpdateCoordinator>() }
    private val repo by lazy { ktx.di().instance<Repo>() }
    private var listener: gs.property.IWhen? = null

    override fun attach(view: View) {
        view as AUpdateView

        val u = repo.content()

        view.update = if (isUpdate(ktx.ctx, u.newestVersionCode))
            u.newestVersionName
        else null

        view.onClick = {
            showSnack(R.string.update_starting)
            updater.start(u.downloadLinks)
        }

        view.onClickBackup = {
            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.data = Uri.parse(u.downloadLinks[next].toString())
            ktx.ctx.startActivity(intent)

            next = next++ % u.downloadLinks.size
        }

        listener = repo.content.doOnUiWhenSet().then {
            val u = repo.content()
            view.update = if (isUpdate(ktx.ctx, u.newestVersionCode)) u.newestVersionName
            else null
        }
    }

    override fun detach(view: View) {
        repo.content.cancel(listener)
        next = 0
    }
}

class StartViewBinder(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val pages: Pages = ktx.di().instance(),
        private val worker: Worker = ktx.di().with("StartViewBinder").instance(),
        private val version: Version = ktx.di().instance(),
        private val welcome: Welcome = ktx.di().instance(),
        private val currentAppVersion: Int,
        private val afterWelcome: () -> Unit
) : ViewBinder, Scrollable, ListSection {

    private enum class Steps { WELCOME, CTA, UPDATED, MULTIPLE_APPS, OBSOLETE }

    private var step = Steps.WELCOME
    private val url by lazy { newProperty(worker, zeroValue = { pages.intro() } ) }

    private val web = WebDash(
            xx = LazyKodein(ktx.di),
            url = url,
            reloadOnError = true,
            javascript = true,
            forceEmbedded = false,
            small = true
    )

    private fun decide() = when {
        version.obsolete() -> Steps.OBSOLETE
        !welcome.introSeen() -> Steps.WELCOME
        version.previousCode() < currentAppVersion -> Steps.UPDATED
        getInstalledBuilds().size > 1 -> Steps.MULTIPLE_APPS
        else -> Steps.CTA
    }

    private fun getUrl(step: Steps) = when(step) {
        Steps.OBSOLETE -> pages.obsolete()
        Steps.WELCOME -> pages.intro()
        Steps.UPDATED -> pages.updated()
        Steps.MULTIPLE_APPS -> pages.cleanup()
        else -> pages.cta()
    }

    private fun performAction(step: Steps) = when(step) {
        Steps.WELCOME -> {
            welcome.introSeen %= true
        }
        Steps.UPDATED -> {
            version.previousCode %= currentAppVersion
        }
        Steps.MULTIPLE_APPS -> {
            showSnack(R.string.welcome_cleanup_done)
            val builds = getInstalledBuilds()
            for (b in builds.subList(1, builds.size).reversed()) {
                uninstallPackage(b)
            }
        }
        else -> Unit
    }

    override fun createView(ctx: Context, parent: ViewGroup): View {
        return web.createView(ctx, parent)
    }

    private var whenPagesLoaded: IWhen? = null
    private var whenObsolete: IWhen? = null
    private var view: View? = null

    override fun attach(view: View) {
        this.view = view
        step = decide()
        url %= getUrl(step)
        web.onAttached {
            performAction(step)
        }
        whenPagesLoaded = pages.loaded.doOnUiWhenChanged(withInit = true).then {
            url %= getUrl(step)
        }
        whenObsolete = version.obsolete.doOnUiWhenChanged(withInit = true).then {
            step = decide()
            url %= getUrl(step)
        }
        return web.attach(view)
    }

    override fun detach(view: View) {
        this.view = null
        web.detach(view)
        pages.loaded.cancel(whenPagesLoaded)
        version.obsolete.cancel(whenObsolete)
    }

    override val viewType = ViewTypeGenerator.get(this)

    override fun setOnScroll(onScrollDown: () -> Unit, onScrollUp: () -> Unit, onScrollStopped: () -> Unit) = Unit

    override fun getScrollableView() = view!!

    override fun setOnSelected(listener: (item: Navigable?) -> Unit) = web.setOnSelected(listener)

    override fun scrollToSelected() = web.scrollToSelected()

    override fun selectNext() = web.selectNext()

    override fun selectPrevious() = web.selectPrevious()

    private fun getInstalledBuilds(): List<String> {
        return welcome.conflictingBuilds().mapNotNull {
            if (isPackageInstalled(it)) it else null
        }
    }

    private fun isPackageInstalled(appId: String): Boolean {
        val intent = ctx.packageManager.getLaunchIntentForPackage(appId) as Intent? ?: return false
        val activities = ctx.packageManager.queryIntentActivities(intent, 0)
        return activities.size > 0
    }

    private fun uninstallPackage(appId: String) {
        try {
            val intent = Intent(Intent.ACTION_DELETE)
            intent.data = Uri.parse("package:" + appId)
            ctx.startActivity(intent)
        } catch (e: Exception) {
        }
    }
}
