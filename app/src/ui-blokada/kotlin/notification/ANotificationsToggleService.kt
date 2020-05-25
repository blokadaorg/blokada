package notification

import android.app.IntentService
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.widget.Toast
import com.github.salomonbrys.kodein.instance
import core.Tunnel
import core.entrypoint
import gs.environment.inject
import org.blokada.R


class ANotificationsToggleService : IntentService("notificationsToggle") {
    private var mHandler: Handler = Handler()

    override fun onHandleIntent(intent: Intent) {
         val newState: Boolean = intent.getBooleanExtra("new_state", true)
        when (intent.getSerializableExtra("setting") as NotificationsToggleSeviceSettings) {
            NotificationsToggleSeviceSettings.GENERAL -> {
                val t: Tunnel = this.inject().instance()
                t.enabled %= newState
                if(newState){
                    mHandler.post(DisplayToastRunnable(this, this.resources.getString(R.string.notification_keepalive_activating)))
                }else{
                    mHandler.post(DisplayToastRunnable(this, this.resources.getString(R.string.notification_keepalive_deactivating)))
                }
            }
            NotificationsToggleSeviceSettings.ADBLOCKING -> {
                entrypoint.onSwitchAdblocking(newState)

            }
            NotificationsToggleSeviceSettings.DNS -> {
                entrypoint.onSwitchDnsEnabled(newState)
            }
            NotificationsToggleSeviceSettings.VPN -> {
                entrypoint.onVpnSwitched(newState)

            }
        }
    }

}

class DisplayToastRunnable(private val mContext: Context, private var mText: String) : Runnable {
    override fun run() {
        Toast.makeText(mContext, mText, Toast.LENGTH_SHORT).show()
    }
}

enum class NotificationsToggleSeviceSettings {
    GENERAL, ADBLOCKING, DNS, VPN
}