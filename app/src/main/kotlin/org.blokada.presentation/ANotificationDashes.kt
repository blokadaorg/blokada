package org.blokada.presentation

import org.blokada.R
import org.blokada.property.State
import org.blokada.ui.app.Dash
import org.blokada.ui.app.UiState
import android.content.Context
import com.github.salomonbrys.kodein.instance
import org.blokada.framework.di

val DASH_ID_KEEPALIVE = "notifiction_keepalive"

class NotificationDashOn(
        val ctx: Context,
        val s: State = ctx.di().instance(),
        val ui: UiState = ctx.di().instance()
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
        val s: State = ctx.di().instance()
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
