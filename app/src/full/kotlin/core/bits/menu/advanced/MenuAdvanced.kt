package core.bits.menu.advanced

import core.AndroidKontext
import core.LabelVB
import core.bits.*
import core.bits.menu.MenuItemsVB
import core.defaultOnTap
import core.res
import gs.presentation.NamedViewBinder
import org.blokada.R

fun createMenuAdvanced(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemsVB(ktx,
            items = listOf(
                    LabelVB(ktx, label = R.string.label_basic.res()),
                    NotificationsVB(ktx, onTap = defaultOnTap),
                    StartOnBootVB(ktx, onTap = defaultOnTap),
                    StorageLocationVB(ktx, onTap = defaultOnTap),
                    LabelVB(ktx, label = R.string.label_advanced.res()),
                    BackgroundAnimationVB(ktx, onTap = defaultOnTap),
                    KeepAliveVB(ktx, onTap = defaultOnTap),
                    WatchdogVB(ktx, onTap = defaultOnTap),
                    PowersaveVB(ktx, onTap = defaultOnTap),
                    ReportVB(ktx, onTap = defaultOnTap)
            ),
            name = R.string.panel_section_app_settings.res()
    )
}
