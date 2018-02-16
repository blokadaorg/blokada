package org.blokada.ui.app.android

import android.content.Context
import com.github.salomonbrys.kodein.instance
import org.blokada.app.android.FirebaseState
import org.blokada.framework.android.di
import org.blokada.R
import org.blokada.ui.app.Dash

val DASH_ID_FIREBASE = "firebase_on"

class FirebaseDashOn(
        val ctx: Context,
        val fState: FirebaseState = ctx.di().instance()
) : Dash(
        DASH_ID_FIREBASE,
        icon = false,
        description = ctx.getBrandedString(R.string.main_tracking_desc),
        text = ctx.getString(R.string.main_tracking_text),
        isSwitch = true
) {
    override var checked = false
        set(value) { if (field != value) {
            field = value
            fState.enabled %= value
            onUpdate.forEach { it() }
        }}

    private val listener: Any
    init {
        listener = fState.enabled.doOnUiWhenSet().then {
            checked = fState.enabled()
        }
    }
}
