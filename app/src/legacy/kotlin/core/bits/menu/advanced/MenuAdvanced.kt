package core.bits.menu.advanced

import adblocker.LoggerVB
import core.AndroidKontext
import core.LabelVB
import core.bits.*
import core.bits.menu.MenuItemVB
import core.bits.menu.MenuItemsVB
import core.defaultOnTap
import core.res
import gs.presentation.NamedViewBinder
import org.blokada.R

private fun createMenuAdvanced(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemsVB(ktx,
            items = listOf(
                    LabelVB(ktx, label = R.string.label_basic.res()),
                    NotificationsVB(ktx, onTap = defaultOnTap),
                    StartOnBootVB(ktx, onTap = defaultOnTap),
                    StorageLocationVB(ktx, onTap = defaultOnTap),
                    LabelVB(ktx, label = R.string.label_advanced.res()),
                    BackgroundAnimationVB(ktx, onTap = defaultOnTap),
                    LoggerVB(ktx, onTap = defaultOnTap),
                    KeepAliveVB(ktx, onTap = defaultOnTap),
                    WatchdogVB(ktx, onTap = defaultOnTap),
                    PowersaveVB(ktx, onTap = defaultOnTap),
                    ReportVB(ktx, onTap = defaultOnTap)
            ),
            name = R.string.panel_section_advanced_settings.res()
    )
}

fun createAdvancedMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_advanced_settings.res(),
            icon = R.drawable.ic_tune.res(),
            opens = createMenuAdvanced(ktx)
    )
}
