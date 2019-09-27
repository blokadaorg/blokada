package core.bits.menu.advanced

import core.AndroidKontext
import core.bits.menu.MenuItemVB
import core.res
import gs.presentation.NamedViewBinder
import org.blokada.R

fun createAdvancedMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_advanced_settings.res(),
            icon = R.drawable.ic_tune.res(),
            opens = createMenuAdvanced(ktx)
    )
}
