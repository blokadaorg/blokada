package core.bits.menu.advanced

import core.AndroidKontext
import core.PaperSource
import core.Register
import core.bits.menu.MenuItemVB
import core.res
import gs.presentation.NamedViewBinder
import org.blokada.R

fun createAdvancedMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_app_settings.res(),
            icon = R.drawable.ic_tune.res(),
            opens = createMenuAdvanced(ktx)
    )
}

data class AdvancedSettings(val enabled: Boolean = false)

fun registerPersistenceForAdvancedSettings() {
    Register.sourceFor(AdvancedSettings::class.java, PaperSource("advanced-settings"),
            default = AdvancedSettings(false))
}
