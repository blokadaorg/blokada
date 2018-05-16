package notification

import android.app.IntentService
import android.content.Intent
import android.widget.Toast
import com.github.salomonbrys.kodein.instance
import core.*
import filter.FilterSourceDescriptor
import filter.id
import gs.environment.inject
import org.blokada.R

class ANotificationsWhitelistService : IntentService("notificationsWhitelist") {

    private val cmd by lazy { inject().instance<Commands>() }

    override fun onHandleIntent(intent: Intent) {
        val host = intent.getStringExtra("host") ?: return

        val f = Filter(
                id(host, whitelist = true),
                source = FilterSourceDescriptor("single", host),
                active = true,
                whitelist = true
        )

        cmd.send(UpdateFilter(f.id, f))
        cmd.send(SyncFilters())
        cmd.send(SyncHostsCache())
        cmd.send(SaveFilters())

        Toast.makeText(this, R.string.notification_blocked_whitelist_applied, Toast.LENGTH_SHORT).show()
        hideNotification(this)
    }

}
