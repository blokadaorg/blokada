package core.bits

import android.content.Context
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.adblocking.SlotMutex
import gs.presentation.ListViewBinder

class AdvancedDashboardSectionVB(
        val ktx: AndroidKontext,
        val ctx: Context = ktx.ctx,
        val battery: Battery = ktx.di().instance()
) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private var items = listOf(
            UpdateVB(ctx.ktx("updateVB"), onTap = slotMutex.openOneAtATime),
            FiltersStatusVB(ctx.ktx("FiltersStatusSlotVB"), onTap = slotMutex.openOneAtATime),
            //ActiveDnsVB(ctx.ktx("currentDns"), onTap = slotMutex.openOneAtATime),
//            VpnStatusVB(ctx.ktx("VpnStatusVB"), onTap = slotMutex.openOneAtATime),
            AboutVB(ctx.ktx("aboutVB"), onTap = slotMutex.openOneAtATime)
    )

    private val batteryVB: BatteryVB = BatteryVB(ctx.ktx("BatteryVB"), onTap = slotMutex.openOneAtATime, onRemove = {
        items = items.subList(0, items.size - 1)
        slotMutex.detach()
        view?.set(items)
    })

    override fun attach(view: VBListView) {
//        if (!battery.isWhitelisted()) items += batteryVB
        view.set(items)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
    }

}
