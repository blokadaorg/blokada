package core

import gs.presentation.ListViewBinder
import gs.presentation.ViewBinder
import org.blokada.R
import tunnel.Events
import tunnel.Filter

internal class SlotMutex {

    private var openedView: SlotView? = null

    val openOneAtATime = { view: SlotView ->
        val opened = openedView
        when {
            opened == null || !opened.isUnfolded() -> {
                openedView = view
                view.unfold()
            }
            opened.isUnfolded() -> {
                opened.fold()
                view.onClose()
            }
        }
    }

    fun detach() {
        openedView = null
    }
}


class FiltersSectionVB(val ktx: AndroidKontext) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private val filtersUpdated = { filters: Collection<Filter> ->
        val items = filters.filter {
            !it.whitelist && !it.hidden && it.source.id != "single"
        }.sortedBy { it.priority }.map { FilterVB(it, ktx, onTap = slotMutex.openOneAtATime) }
        view?.set(listOf(NewFilterVB(ktx, nameResId = R.string.slot_new_filter_list)) + items)
        onSelectedListener(null)
        Unit
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        ktx.on(Events.FILTERS_CHANGED, filtersUpdated)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        ktx.cancel(Events.FILTERS_CHANGED, filtersUpdated)
    }

}

class StaticItemsListVB(
        private val items: List<ViewBinder>
) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    init {
        items.filter { it is SlotVB }.forEach {
            (it as SlotVB).onTap = slotMutex.openOneAtATime
        }
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        view.set(items)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
    }
}
