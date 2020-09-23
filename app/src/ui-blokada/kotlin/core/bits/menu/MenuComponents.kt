package core.bits.menu

import android.content.Context
import android.content.res.Configuration
import core.*
import gs.presentation.ListViewBinder
import gs.presentation.NamedViewBinder
import gs.presentation.ViewBinder
import org.blokada.R

fun isLandscape(ctx: Context): Boolean {
    return ctx.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
}

class MenuItemsVB(
        val ktx: AndroidKontext,
        val items: List<ViewBinder>,
        override val name: Resource = R.string.panel_section_menu.res()
) : ListViewBinder(), NamedViewBinder {

    override fun attach(view: VBListView) {
        view.enableAlternativeMode()
        view.set(items)
    }

    override fun detach(view: VBListView) {
    }

}

class MenuItemVB(
        val ktx: Kontext,
        val label: Resource,
        val icon: Resource,
        val opens: NamedViewBinder,
        override val name: Resource = label
): BitVB(), NamedViewBinder {

    override fun attach(view: BitView) {
        view.label(label, R.color.colorActive.res())
        view.icon(icon, R.color.colorActive.res())
        view.arrow(true)
        view.alternative(true)
        view.onTap {
            ktx.emit(MENU_CLICK, opens)
        }
    }

    override fun detach(view: BitView) {
        view.onTap {}
    }
}

class SimpleMenuItemVB(
        val ktx: AndroidKontext,
        val label: Resource,
        val icon: Resource,
        val action: (ktx: AndroidKontext) -> Unit,
        val longAction: ((ktx: AndroidKontext) -> Unit)? = null,
        val arrow: Boolean = true,
        override val name: Resource = label
): BitVB(), NamedViewBinder {

    override fun attach(view: BitView) {
        view.label(label, R.color.colorActive.res())
        view.icon(icon, R.color.colorActive.res())
        view.arrow(arrow)
        view.alternative(true)
        view.onTap {
            action(ktx)
        }
        if (longAction != null) {
            view.setOnLongClickListener {
                longAction.invoke(ktx)
                true
            }
        }
    }

    override fun detach(view: BitView) {
        view.onTap {}
    }
}

val MENU_CLICK = "MENU_CLICK".newEventOf<NamedViewBinder>()
val MENU_CLICK_BY_NAME = "MENU_CLICK_BY_NAME".newEventOf<Resource>()
val MENU_CLICK_BY_NAME_SUBMENU = "MENU_CLICK_BY_NAME_SUBMENU".newEventOf<Pair<Resource, Resource>>()
