package core

import android.content.Context
import gs.presentation.ListViewBinder

class AdvancedDashboardSectionVB(val ctx: Context) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private val items = mutableListOf(
            FiltersStatusVB(ctx.ktx("FiltersStatusSlotVB"), onTap = slotMutex.openOneAtATime),
            ActiveDnsVB(ctx.ktx("currentDns"), onTap = slotMutex.openOneAtATime),
            UpdateVB(ctx.ktx("updateVB"), onTap = slotMutex.openOneAtATime),
            TelegramVB(ctx.ktx("telegramVB"), onTap = slotMutex.openOneAtATime),
            ShareLogVB(ctx.ktx("shareLogVB"), onTap = slotMutex.openOneAtATime)
    )

    override fun attach(view: VBListView) {
        view.set(items)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
    }

}
