package core.bits.menu.adblocking

import core.AndroidKontext
import core.LabelVB
import core.bits.Adblocking2VB
import core.bits.menu.MenuItemVB
import core.bits.menu.MenuItemsVB
import core.res
import gs.presentation.NamedViewBinder
import org.blokada.R

private fun createMenuAdblocking(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemsVB(ktx,
            items = listOf(
                Adblocking2VB(ktx),
                LabelVB(ktx, label = R.string.menu_ads_lists_label.res()),
                createHostsListMenuItem(ktx),
                createHostsListDownloadMenuItem(ktx),
                LabelVB(ktx, label = R.string.menu_ads_rules_label.res()),
                createWhitelistMenuItem(ktx),
                createBlacklistMenuItem(ktx),
                LabelVB(ktx, label = R.string.menu_ads_log_label.res()),
                createHostsLogMenuItem(ktx)
            ),
            name = R.string.panel_section_ads.res()
    )
}

fun createAdblockingMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_ads.res(),
            icon = R.drawable.ic_blocked.res(),
            opens = createMenuAdblocking(ktx)
    )
}
