package notification

import android.app.IntentService
import android.content.Intent
import android.widget.Toast
import com.github.salomonbrys.kodein.instance
import core.ktx
import filter.id
import gs.environment.inject
import org.blokada.R
import tunnel.Filter
import tunnel.FilterSourceDescriptor

class ANotificationsWhitelistService : IntentService("notificationsWhitelist") {

    private val tunnel by lazy { inject().instance<tunnel.Main>() }

    override fun onHandleIntent(intent: Intent) {
        val host = intent.getStringExtra("host") ?: return

        val f = Filter(
                id(host, whitelist = true, wildcard = false),
                source = FilterSourceDescriptor("single", host),
                active = true,
                whitelist = true,
                wildcard = false
        )

        tunnel.putFilter(ktx("whitelistFromNotification"), f)

        Toast.makeText(this, R.string.notification_blocked_whitelist_applied, Toast.LENGTH_SHORT).show()
        hideNotification(this)
    }

}
