package core.bits

import android.app.Activity
import android.graphics.Point
import com.github.michaelbull.result.onSuccess
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.adblocking.SlotMutex
import core.bits.menu.isLandscape
import gs.environment.ComponentProvider
import gs.presentation.ListViewBinder
import gs.presentation.NamedViewBinder
import org.blokada.R
import tunnel.TunnelEvents
import tunnel.Request
import kotlin.math.max

class AdsDashboardSectionVB(
        val ktx: AndroidKontext,
        val activity: ComponentProvider<Activity> = ktx.di().instance(),
        override val name: Resource = R.string.menu_ads.res()
) : ListViewBinder(), NamedViewBinder {

    private val screenHeight: Int by lazy {
        val point = Point()
        activity.get()?.windowManager?.defaultDisplay?.getSize(point)
        if (point.y > 0) point.y else 2000
    }

    private val countLimit: Int by lazy {
        val limit = screenHeight / ktx.ctx.dpToPx(80)
        max(5, limit)
    }

    private val displayingEntries = mutableListOf<String>()
    private val slotMutex = SlotMutex()

    private val items = mutableListOf<SlotVB>()

    private val request = { it: Request ->
        if (!displayingEntries.contains(it.domain)) {
            displayingEntries.add(it.domain)
            val dash = if (it.blocked)
                DomainBlockedVB(it.domain, it.time, ktx, onTap = slotMutex.openOneAtATime) else
                DomainForwarderVB(it.domain, it.time, ktx, onTap = slotMutex.openOneAtATime)
            items.add(dash)
            view?.add(dash)
            trimListIfNecessary()
            onSelectedListener(null)
        }
        Unit
    }

    private fun trimListIfNecessary() {
        if (items.size > countLimit) {
            items.firstOrNull()?.apply {
                items.remove(this)
                view?.remove(this)
            }
        }
    }

    override fun attach(view: VBListView) {
        if (isLandscape(ktx.ctx)) {
            view.enableLandscapeMode(reversed = false)
        }

        tunnel.Persistence.request.load(0).onSuccess {
            it.forEach(request)
        }
        ktx.on(TunnelEvents.REQUEST, request)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        displayingEntries.clear()
        ktx.cancel(TunnelEvents.REQUEST, request)
    }
}
