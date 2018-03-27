package notification

import android.content.Context
import com.github.salomonbrys.kodein.instance
import core.Dash
import core.Filters
import core.KeepAlive
import core.UiState
import gs.environment.inject
import org.blokada.R

val DASH_ID_KEEPALIVE = "notifiction_keepalive"

class NotificationDashOn(
        val ctx: Context,
        val s: Filters = ctx.inject().instance(),
        val ui: UiState = ctx.inject().instance()
) : Dash(
        "notification_on",
        icon = false,
        text = ctx.getString(R.string.notification_on_text),
        isSwitch = true
) {
    override var checked = false
        set(value) { if (field != value) {
            field = value
            ui.notifications %= value
            onUpdate.forEach { it() }
        }}

    private val listener: Any
    init {
        listener = ui.notifications.doOnUiWhenSet().then {
            checked = ui.notifications()
        }
    }
}

class NotificationDashKeepAlive(
        val ctx: Context,
        val s: KeepAlive = ctx.inject().instance()
) : Dash(
        DASH_ID_KEEPALIVE,
        icon = false,
        text = ctx.getString(R.string.notification_keepalive_text),
        isSwitch = true
) {
    override var checked = false
        set(value) { if (field != value) {
            field = value
            s.keepAlive %= value
            onUpdate.forEach { it() }
        }}

    private val listener: Any
    init {
        listener = s.keepAlive.doOnUiWhenSet().then {
            checked = s.keepAlive()
        }
    }
}
