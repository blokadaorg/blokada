package core

import android.app.Activity
import com.github.michaelbull.result.getOr
import com.github.salomonbrys.kodein.instance
import gs.environment.ComponentProvider
import gs.presentation.ListViewBinder
import tunnel.Events
import tunnel.Persistence
import tunnel.Request

class AdsLogVB(
        val ktx: AndroidKontext,
        val activity: ComponentProvider<Activity> = ktx.di().instance()
) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private val items = mutableListOf<SlotVB>()
    private var nextBatch = 0
    private var firstItem: Request? = null
    private var listener: (SlotVB?) -> Unit = {}

    private val request = { it: Request ->
        if (it != firstItem) {
            val dash = requestToVB(it)
            items.add(0, dash)
            view?.add(dash, 0)
            firstItem = it
            onSelectedListener(null)
        }
        Unit
    }

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        if (items.isEmpty()) {
            var items = loadBatch(0)
            items += loadBatch(1)
            nextBatch = 2
            if (items.isEmpty()) {
                items += loadBatch(2)
                nextBatch = 3
            }
            firstItem = items.getOrNull(0)
            addBatch(items)
        } else {
            items.forEach { view.add(it) }
        }
        ktx.on(Events.REQUEST, request)
        view.onEndReached = loadMore
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        view.onEndReached = {}
        ktx.cancel(Events.REQUEST, request)
    }

    private val loadMore = {
        if (nextBatch < 3) addBatch(loadBatch(nextBatch++))
    }

    private fun loadBatch(batch: Int) = Persistence.request.load(batch).getOr { emptyList() }
    private fun addBatch(batch: List<Request>) {
        items.addAll(batch.map {
            val dash = requestToVB(it)
            view?.add(dash)
            dash
        })
    }

    private fun requestToVB(it: Request): SlotVB {
        return if (it.blocked)
            DomainBlockedVB(it.domain, it.time, ktx, alternative = true, onTap = slotMutex.openOneAtATime) else
            DomainForwarderVB(it.domain, it.time, ktx, alternative = true, onTap = slotMutex.openOneAtATime)
    }
}
