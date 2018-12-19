package core

import android.content.Context
import com.github.salomonbrys.kodein.instance
import gs.presentation.ListViewBinder
import gs.property.IWhen

class DnsDashboardSection(val ctx: Context) : ListViewBinder() {

    private val ktx = ctx.ktx("DnsDashboard")
    private val filters by lazy { ktx.di().instance<Filters>() }
    private val dns by lazy { ktx.di().instance<Dns>() }

    private val slotMutex = SlotMutex()

    private var get: IWhen? = null

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        filters.apps.refresh()
        get = dns.choices.doOnUiWhenSet().then {
            dns.choices().map {
                DnsChoiceVB(it, ktx, onTap = slotMutex.openOneAtATime)
            }.apply { view.set(this) }
        }
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        dns.choices.cancel(get)
    }

}
