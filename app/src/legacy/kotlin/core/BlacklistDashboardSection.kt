package core

import gs.presentation.ListViewBinder
import tunnel.Events
import tunnel.Filter

class BlacklistDashboardSection(val ktx: AndroidKontext) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private var updateApps = { filters: Collection<Filter> ->
        filters.filter { !it.whitelist && !it.hidden && it.source.id == "single" }.map {
            FilterVB(it, ktx, onTap = slotMutex.openOneAtATime)
        }.apply { view?.set(listOf(NewFilterVB(ktx)) + this) }
        Unit
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        ktx.on(Events.FILTERS_CHANGED, updateApps)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        ktx.cancel(Events.FILTERS_CHANGED, updateApps)
    }

}
