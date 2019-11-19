package core.bits.menu.apps

import android.content.Context
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.AppVB
import core.bits.SearchBarVB
import core.bits.menu.adblocking.SlotMutex
import gs.presentation.ListViewBinder
import gs.presentation.NamedViewBinder
import gs.property.IWhen
import org.blokada.R
import tunnel.TunnelEvents
import tunnel.Filter

class AllAppsDashboardSectionVB(
        val ctx: Context,
        val system: Boolean,
        override val name: Resource = if (system) R.string.panel_section_apps_system.res() else R.string.panel_section_apps_all.res()
) : ListViewBinder(), NamedViewBinder {

    private val ktx = ctx.ktx("AllAppsDashboard")
    private val filters by lazy { ktx.di().instance<Filters>() }
    private val filterManager by lazy { ktx.di().instance<tunnel.TunnelMain>() }

    private val slotMutex = SlotMutex()

    private var apps: List<App> = emptyList()
    private var fil: Collection<String> = emptyList()
    private var filLoaded = false

    private var updateApps = { filters: Collection<Filter> ->
        fil = filters.filter { it.source.id == "app" && it.active }.map { it.source.source }
        filLoaded = true
        updateListing()
        Unit
    }

    private var getApps: IWhen? = null

    private fun updateListing(keyword: String = "") {
        if (apps.isEmpty() || !filLoaded) return

        val whitelisted = apps.filter { (it.appId in fil) && (keyword.isEmpty() || it.label.toLowerCase().contains(keyword.toLowerCase())) }.sortedBy { it.label.toLowerCase() }
        val notWhitelisted = apps.filter { (it.appId !in fil) && (keyword.isEmpty() || it.label.toLowerCase().contains(keyword.toLowerCase())) }.sortedBy { it.label.toLowerCase() }

        val listing = listOf(LabelVB(ktx, label = R.string.slot_allapp_whitelisted.res())) +
                whitelisted.map { AppVB(it, true, ktx, onTap = slotMutex.openOneAtATime) } +
                LabelVB(ktx, label = R.string.slot_allapp_normal.res()) +
                notWhitelisted.map { AppVB(it, false, ktx, onTap = slotMutex.openOneAtATime) }
        view?.set(listing)
        view?.add(SearchBarVB(ktx, onSearch = { s ->
            updateListing(s)
        }), 0)
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        ktx.on(TunnelEvents.FILTERS_CHANGED, updateApps)
        filters.apps.refresh()
        getApps = filters.apps.doOnUiWhenSet().then {
            apps = filters.apps().filter { it.system == system }
            updateListing()
        }
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        ktx.cancel(TunnelEvents.FILTERS_CHANGED, updateApps)
        filters.apps.cancel(getApps)
    }

}
