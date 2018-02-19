package org.blokada.presentation

import android.content.Context
import android.view.View
import android.widget.PopupMenu
import com.github.salomonbrys.kodein.instance
import gs.environment.Journal
import org.blokada.R
import org.blokada.main.Events
import org.blokada.presentation.ContentActor.Companion.X_END
import org.blokada.property.Dash
import org.blokada.property.UiState
import org.obsolete.di


class DashNoop : Dash("main_noop", icon = false)

class DashMainMenu(
        val ctx: Context,
        val ui: UiState,
        val contentActor: ContentActor
) : Dash(
        "main_menu",
        R.drawable.ic_more
) {

    private val a by lazy { ctx.di().instance<Journal>() }
    private var menu: PopupMenu? = null

    init {
        onClick = { dashRef ->
            if (menu == null && dashRef is View) {
                menu = PopupMenu(ctx, dashRef)
                val m = menu!!.menu
                m.add(0, 1, 1, R.string.main_patron)
                m.add(0, 2, 2, R.string.main_patron_about)
                m.add(0, 3, 3, R.string.main_donate_text)
                m.add(0, 4, 4, R.string.main_contribute_text)
                m.add(0, 5, 5, R.string.main_blog_text)
                m.add(0, 6, 6, R.string.main_faq_text)
                m.add(0, 7, 7, R.string.update_about)
                m.add(0, 8, 8, R.string.main_changelog)
                m.add(0, 9, 9, R.string.main_feedback_text)
                menu!!.setOnMenuItemClickListener { openMenu(it.itemId); true }
            }
            menu!!.show()
            false
        }
    }

    private val openMenu = { itemId: Int ->
        val dash = when (itemId) {
            1 -> ui.dashes().firstOrNull { it.id == DASH_ID_PATRON }
            2 -> ui.dashes().firstOrNull { it.id == DASH_ID_PATRON_ABOUT }
            3 -> ui.dashes().firstOrNull { it.id == DASH_ID_DONATE }
            4 -> ui.dashes().firstOrNull { it.id == DASH_ID_CONTRIBUTE }
            5 -> ui.dashes().firstOrNull { it.id == DASH_ID_BLOG }
            6 -> ui.dashes().firstOrNull { it.id == DASH_ID_FAQ }
            7 -> ui.dashes().firstOrNull { it.id == DASH_ID_ABOUT }
            8 -> ui.dashes().firstOrNull { it.id == DASH_ID_CHANGELOG }
            9 -> ui.dashes().firstOrNull { it.id == DASH_ID_FEEDBACK }
            else -> null
        }
        if (dash != null) {
            contentActor.back {
                a.event(Events.Companion.CLICK_DASH(dash.id))
                contentActor.reveal(dash, X_END, 0)
            }
        }
    }
}

