package core.bits.menu.dns

import core.AndroidKontext
import core.bits.menu.MenuItemVB
import core.res
import gs.presentation.NamedViewBinder
import org.blokada.R

fun createDnsMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_advanced_dns.res(),
            icon = R.drawable.ic_server.res(),
            opens = DnsDashboardSection(ktx.ctx)
    )
}
