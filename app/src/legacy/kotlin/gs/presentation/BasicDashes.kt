package gs.presentation

import android.content.Context
import android.view.ViewGroup
import android.widget.PopupMenu
import org.blokada.R


class MenuDash(
        val menuDashes: Map<ViewBinder, String>,
        val dashCoordinator: DashCoordinator
) : IconDash() {

    private var menu: android.widget.PopupMenu? = null

    override fun attachIcon(v: IconDashView) {
        if (menu == null) menu = initMenu(v.context, v)
        v.iconRes = R.drawable.ic_more
        v.onClick = { menu?.show() }
    }

    private fun initMenu(ctx: Context, parent: ViewGroup): PopupMenu {
        val menu = PopupMenu(ctx, parent)
        val m = menu.menu
        var count = 1
        menuDashes.forEach { (d, label) ->
            m.add(0, d.hashCode(), count++, label)
        }
        menu.setOnMenuItemClickListener { openMenuItem(it.itemId); true }
        return menu
    }

    private val openMenuItem = { itemId: Int ->
        val dash = menuDashes.entries.first { it.key.hashCode() == itemId }.key
        dashCoordinator.back {
            dashCoordinator.reveal(dash, x = DashCoordinator.X_END, y = 0)
        }
    }
}

