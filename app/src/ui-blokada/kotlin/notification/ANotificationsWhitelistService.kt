package notification

import android.app.IntentService
import android.content.Intent
import android.os.Handler
import com.github.salomonbrys.kodein.instance
import core.id
import core.ktx
import gs.environment.inject
import org.blokada.R
import tunnel.Filter
import tunnel.FilterSourceDescriptor

class ANotificationsWhitelistService : IntentService("notificationsWhitelist") {

    private val tunnel by lazy { inject().instance<tunnel.Main>() }
    private var mHandler: Handler = Handler()

    override fun onHandleIntent(intent: Intent) {
        val host = intent.getStringExtra("host") ?: return

        val f = Filter(
                id(host, whitelist = true),
                source = FilterSourceDescriptor("single", host),
                active = true,
                whitelist = true
        )

        tunnel.putFilter(ktx("whitelistFromNotification"), f)

        mHandler.post(DisplayToastRunnable(this, getString(R.string.notification_blocked_whitelist_applied)))
        hideNotification(this)
    }

}
