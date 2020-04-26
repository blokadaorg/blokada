package core.bits.menu.advanced

import android.widget.Toast
import core.*
import core.Register.set
import core.bits.*
import core.bits.menu.MenuItemsVB
import gs.presentation.NamedViewBinder
import org.blokada.R

fun createMenuAdvanced(ktx: AndroidKontext): NamedViewBinder {
    var items = listOf(
        LabelVB(ktx, label = R.string.label_basic.res()),
        NotificationsVB(ktx, onTap = defaultOnTap),
        StartOnBootVB(ktx, onTap = defaultOnTap),
        LabelVB(ktx, label = R.string.label_advanced.res(), hiddenAction = {
            set(AdvancedSettings::class.java, AdvancedSettings(true))
            Toast.makeText(ktx.ctx, "( ͡° ͜ʖ ͡°)", Toast.LENGTH_LONG).show()
        }),
        ReportVB(ktx, onTap = defaultOnTap),
        BackgroundAnimationVB(ktx, onTap = defaultOnTap),
        KeepAliveVB(ktx, onTap = defaultOnTap)
    )

    if (get(AdvancedSettings::class.java).enabled) {
        items += listOf(
            WatchdogVB(ktx, onTap = defaultOnTap),
            PowersaveVB(ktx, onTap = defaultOnTap),
            StorageLocationVB(ktx, onTap = defaultOnTap)
        )
    }

    return MenuItemsVB(
        ktx,
        items = items,
        name = R.string.panel_section_app_settings.res()
    )
}
