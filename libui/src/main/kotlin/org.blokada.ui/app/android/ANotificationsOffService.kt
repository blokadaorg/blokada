package org.blokada.ui.app.android

import android.app.IntentService
import android.content.Intent
import com.github.salomonbrys.kodein.instance
import org.blokada.framework.android.di
import org.blokada.ui.app.UiState


/**
 * ANotificationsOffService turns off notifications once intent is sent to it.
 */
class ANotificationsOffService : IntentService("notification") {

    private val state by lazy { di().instance<UiState>() }

    override fun onHandleIntent(intent: Intent) {
        state.notifications %= false
    }

}
