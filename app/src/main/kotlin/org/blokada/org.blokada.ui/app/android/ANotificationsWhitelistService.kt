package org.blokada.ui.app.android

import android.app.IntentService
import android.content.Intent
import android.widget.Toast
import com.github.salomonbrys.kodein.instance
import nl.komponents.kovenant.ui.promiseOnUi
import org.blokada.app.Filter
import org.blokada.app.FilterSourceSingle
import org.blokada.app.LocalisedFilter
import org.blokada.framework.android.di
import org.blokada.R
import org.blokada.app.State

class ANotificationsWhitelistService : IntentService("notificationWhitelist") {

    private val s by lazy { di().instance<State>() }

    override fun onHandleIntent(intent: Intent) {
        val host = intent.getStringExtra("host") as String? ?: return

        val filter = Filter(
                id = host,
                source = FilterSourceSingle(host),
                active = true,
                whitelist = true,
                localised = LocalisedFilter(host)
        )

        val existing = s.filters().firstOrNull { it == filter }
        if (existing == null) {
            s.filters %= s.filters() + filter
        } else if (!existing.active) {
            existing.active = true
            s.filters %= s.filters() // TODO: not sure if it's nice
        }

        promiseOnUi {
            Toast.makeText(this, R.string.notification_blocked_whitelist_applied, Toast.LENGTH_SHORT).show()
            hideNotification(this)
        }
    }

}
