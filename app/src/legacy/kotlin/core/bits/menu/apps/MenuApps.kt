package core.bits.menu.apps

import core.AndroidKontext
import core.LabelVB
import core.bits.menu.MenuItemVB
import core.bits.menu.MenuItemsVB
import core.res
import gs.presentation.NamedViewBinder
import org.blokada.R

fun createAppsMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_apps.res(),
            icon = R.drawable.ic_apps.res(),
            opens = createMenuApps(ktx)
    )
}

private fun createMenuApps(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemsVB(ktx,
            items = listOf(
                    LabelVB(ktx, label = R.string.menu_apps_intro.res()),
                    createInstalledAppsMenuItem(ktx),
                    LabelVB(ktx, label = R.string.menu_apps_system_label.res()),
                    createAllAppsMenuItem(ktx)
            ),
            name = R.string.panel_section_apps.res()
    )
}

private fun createInstalledAppsMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_apps_all.res(),
            icon = R.drawable.ic_apps.res(),
            opens = AllAppsDashboardSectionVB(ktx.ctx, system = false))
}

private fun createAllAppsMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.panel_section_apps_system.res(),
            icon = R.drawable.ic_apps.res(),
            opens = AllAppsDashboardSectionVB(ktx.ctx, system = true))
}
