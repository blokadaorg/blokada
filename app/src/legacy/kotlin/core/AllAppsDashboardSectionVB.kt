package core

import android.content.Context
import com.github.salomonbrys.kodein.instance
import gs.presentation.ListViewBinder
import gs.property.IWhen
import tunnel.Events
import tunnel.Filter

class AllAppsDashboardSectionVB(val ctx: Context, val system: Boolean) : ListViewBinder() {

    private val ktx = ctx.ktx("AllAppsDashboard")
    private val filters by lazy { ktx.di().instance<Filters>() }
    private val filterManager by lazy { ktx.di().instance<tunnel.Main>() }

    private val slotMutex = SlotMutex()

    private var updateApps = { filters: Collection<Filter> ->
        Unit
    }

    private var getApps: IWhen? = null

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        ktx.on(Events.FILTERS_CHANGED, updateApps)
        filters.apps.refresh()
        getApps = filters.apps.doOnUiWhenSet().then {
            filters.apps().filter { it.system == system }.map {
                AppVB(it, ktx, onTap = slotMutex.openOneAtATime)
            }.apply { view.set(this) }
        }
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        ktx.cancel(Events.FILTERS_CHANGED, updateApps)
        filters.apps.cancel(getApps)
    }

}
