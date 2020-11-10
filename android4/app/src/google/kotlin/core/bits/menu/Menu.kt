package core.bits.menu

import core.AndroidKontext
import core.LabelVB
import core.bits.menu.advanced.createAdvancedMenuItem
import core.bits.menu.apps.createAppsMenuItem
import core.bits.menu.dns.createDnsMenuItem
import core.bits.menu.vpn.createVpnMenuItem
import core.res
import org.blokada.R

fun createMenu(ktx: AndroidKontext): MenuItemsVB {
    return MenuItemsVB(ktx,
            items = listOf(
                    LabelVB(ktx, label = R.string.menu_configure.res()),
                    createDnsMenuItem(ktx),
                    createVpnMenuItem(ktx),
                    LabelVB(ktx, label = R.string.menu_exclude.res()),
                    createAppsMenuItem(ktx),
                    LabelVB(ktx, label = R.string.menu_dive_in.res()),
                    createAdvancedMenuItem(ktx),
                    createLearnMoreMenuItem(ktx),
                    createAboutMenuItem(ktx)
            ),
            name = R.string.panel_section_menu.res()
    )
}

