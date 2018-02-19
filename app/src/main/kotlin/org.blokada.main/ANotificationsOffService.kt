package org.blokada.main

import android.app.IntentService
import android.content.Intent
import com.github.salomonbrys.kodein.instance
import gs.environment.inject
import org.blokada.property.UiState


/**
 * ANotificationsOffService turns off notifications once intent is sent to it.
 */
class ANotificationsOffService : IntentService("notification") {

    private val state by lazy { inject().instance<UiState>() }

    override fun onHandleIntent(intent: Intent) {
        state.notifications %= false
    }

}
