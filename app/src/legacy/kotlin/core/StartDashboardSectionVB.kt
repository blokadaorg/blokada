package core

import com.github.salomonbrys.kodein.instance
import gs.presentation.ListViewBinder
import gs.presentation.ViewBinder

class StartDashboardSectionVB(
        val ktx: AndroidKontext,
        val pages: Pages = ktx.di().instance()
) : ListViewBinder() {

    private val slotMutex = SlotMutex()

    private var items = listOf<ViewBinder>(
            AdblockingVB(ktx, onTap = slotMutex.openOneAtATime)
//            StartOnBootVB(ktx, onTap = slotMutex.openOneAtATime),
//            RecommendedDnsVB(ktx, onTap = slotMutex.openOneAtATime)
            //StartViewBinder(ktx, currentAppVersion = BuildConfig.VERSION_CODE, afterWelcome = {})
    )

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        view.set(items)
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
    }
}
