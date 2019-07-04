package core

import android.content.Context
import com.github.salomonbrys.kodein.instance
import gs.presentation.ListViewBinder
import tunnel.Events
import tunnel.Filter

class AppsDashboardSectionVB(val ctx: Context) : ListViewBinder() {

    private val ktx = ctx.ktx("AppsDashboard")
    private val filters by lazy { ktx.di().instance<Filters>() }
    private val filterManager by lazy { ktx.di().instance<tunnel.Main>() }

    private val slotMutex = SlotMutex()

    private var updateApps = { filters: Collection<Filter> ->
        filters.filter { it.source.id == "app" }
                .filter { it.active }
                .map {
            HomeAppVB(it, ktx, onTap = slotMutex.openOneAtATime)
        }.apply { view?.set(this) }
        Unit
    }

    override fun attach(view: VBListView) {
        ktx.on(Events.FILTERS_CHANGED, updateApps)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        ktx.cancel(Events.FILTERS_CHANGED, updateApps)
    }
}
