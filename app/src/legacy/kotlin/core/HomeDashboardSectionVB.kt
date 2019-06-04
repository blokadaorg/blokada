package core

import android.content.Context
import com.github.salomonbrys.kodein.LazyKodein
import gs.presentation.ListViewBinder
import gs.presentation.ViewBinder
import gs.property.BasicPersistence

class HomeDashboardSectionVB(
        val ktx: AndroidKontext,
        val ctx: Context = ktx.ctx,
        val introPersistence: BasicPersistence<Boolean> = BasicPersistence(LazyKodein(ktx.di), "intro_vb")
) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private val intro: IntroVB = IntroVB(ctx.ktx("InfoSlotVB"), onTap = slotMutex.openOneAtATime, onRemove = {
        items = items.subList(1, items.size)
        view?.set(items)
        slotMutex.detach()
        introPersistence.write(true)
    })

    private var items = listOf<ViewBinder>(
            ProtectionVB(ctx.ktx("ProtectionVB"), onTap = slotMutex.openOneAtATime),
            AppStatusVB(ctx.ktx("AppStatusSlotVB"), onTap = slotMutex.openOneAtATime),
            HomeNotificationsVB(ctx.ktx("NotificationsVB"), onTap = slotMutex.openOneAtATime)
    )

    override fun attach(view: VBListView) {
        if (!introPersistence.read(false)) items = listOf(intro) + items
        view.set(items)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
    }

}
