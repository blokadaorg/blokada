package core.bits.menu.dns

import android.content.Context
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.*
import core.bits.menu.adblocking.SlotMutex
import gs.presentation.ListViewBinder
import gs.presentation.NamedViewBinder
import gs.property.IWhen
import org.blokada.R

class DnsDashboardSection(
        val ctx: Context,
        override val name: Resource = R.string.panel_section_advanced_dns.res()
) : ListViewBinder(), NamedViewBinder {

    private val ktx = ctx.ktx("DnsDashboard")
    private val filters by lazy { ktx.di().instance<Filters>() }
    private val dns by lazy { ktx.di().instance<Dns>() }

    private val slotMutex = SlotMutex()

    private var get: IWhen? = null

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        filters.apps.refresh()
        get = dns.choices.doOnUiWhenSet().then {
            val default = dns.choices().firstOrNull()
            val active = dns.choices().filter { it.active }
            val inactive = dns.choices().filter { !it.active }

            val defaultList = if (default != null) listOf(default) else emptyList()

            (defaultList + active.minus(defaultList) + inactive.minus(defaultList)).map {
                DnsChoiceVB(it, ktx, onTap = slotMutex.openOneAtATime)
            }.apply {
                view.set(this)
                view.add(LabelVB(ktx, label = R.string.menu_dns_intro.res()), 0)
                view.add(MenuActiveDnsVB(ktx), 1)
                view.add(AddDnsVB(ktx), 2)
                view.add(LabelVB(ktx, label = R.string.menu_dns_recommended.res()), 3)
                view.add(LabelVB(ktx, label = R.string.menu_manage.res()))
                view.add(DnsListControlVB(ktx, onTap = defaultOnTap))
                view.add(DnsFallbackVB(ktx, onTap = defaultOnTap))
            }
        }
    }

    override fun detach(view: VBListView) {
        slotMutex.detach()
        dns.choices.cancel(get)
    }

}
