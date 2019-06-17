package core

import android.content.Context
import com.github.salomonbrys.kodein.instance
import gs.presentation.ListViewBinder
import gs.property.IWhen
import org.blokada.R
import tunnel.Events
import tunnel.Filter

class AllAppsDashboardSectionVB(val ctx: Context, val system: Boolean) : ListViewBinder() {

    private val ktx = ctx.ktx("AllAppsDashboard")
    private val filters by lazy { ktx.di().instance<Filters>() }
    private val filterManager by lazy { ktx.di().instance<tunnel.Main>() }

    private val slotMutex = SlotMutex()

    private var apps: List<App> = emptyList()
    private var fil: Collection<String> = emptyList()

    private var updateApps = { filters: Collection<Filter> ->
        fil = filters.filter { it.source.id == "app" }.map { it.source.source }
        updateListing()
        Unit
    }

    private var getApps: IWhen? = null

    private fun updateListing(keyword: String = "") {
        if (apps.isEmpty() || fil.isEmpty()) return

        val whitelisted = apps.filter { (it.appId in fil) && (keyword.isEmpty() || it.label.toLowerCase().contains(keyword.toLowerCase())) }
        val notWhitelisted = apps.filter { (it.appId !in fil) && (keyword.isEmpty() || it.label.toLowerCase().contains(keyword.toLowerCase())) }

        val listing = listOf(LabelVB(labelResId = R.string.slot_allapp_whitelisted)) +
                whitelisted.map { AppVB(it, true, ktx, onTap = slotMutex.openOneAtATime) } +
                LabelVB(labelResId = R.string.slot_allapp_normal) +
                notWhitelisted.map { AppVB(it, false, ktx, onTap = slotMutex.openOneAtATime) }
        view?.set(listing)
        view?.add(SearchBarVB(ctx, { s ->
            updateListing(s)
        }),0)
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        ktx.on(Events.FILTERS_CHANGED, updateApps)
        filters.apps.refresh()
        getApps = filters.apps.doOnUiWhenSet().then {
            apps = filters.apps().filter { it.system == system }
            updateListing()
        }
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        ktx.cancel(Events.FILTERS_CHANGED, updateApps)
        filters.apps.cancel(getApps)
    }

}
