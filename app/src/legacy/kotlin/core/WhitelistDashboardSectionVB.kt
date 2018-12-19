package core

import gs.presentation.ListViewBinder
import tunnel.Events
import tunnel.Filter

class WhitelistDashboardSectionVB(val ktx: AndroidKontext) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private var updateApps = { filters: Collection<Filter> ->
        filters.filter { it.whitelist && !it.hidden && it.source.id != "app" }.map {
            FilterVB(it, ktx, onTap = slotMutex.openOneAtATime)
        }.apply { view?.set(listOf(NewFilterVB(ktx, whitelist = true)) + this) }
        Unit
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        ktx.on(Events.FILTERS_CHANGED, updateApps)
    }
}
