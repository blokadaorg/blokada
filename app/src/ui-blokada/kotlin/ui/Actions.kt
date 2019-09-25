package ui

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.widget.Toast
import com.github.salomonbrys.kodein.instance
import com.twofortyfouram.locale.sdk.client.receiver.AbstractPluginSettingReceiver
import core.Tunnel
import core.bits.menu.shareLog
import core.e
import core.ktx
import core.v
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.delay
import org.blokada.R

class SendLogActivity : Activity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        //initGlobal(this, failsafe = true)
        shareLog(this)
        async {
            delay(2000)
            finish()
        }
        //System.exit(0)
    }
}

val EVENT_KEY_SWITCH = "blokada_switch"

class SwitchAppReceiver : AbstractPluginSettingReceiver() {

    override fun isAsync(): Boolean {
        return false
    }

    override fun firePluginSetting(ctx: Context, bundle: Bundle) {
        try {
            val switch = bundle.getBoolean(EVENT_KEY_SWITCH)
            v("switching app from intent", switch)

            val ktx = ctx.ktx("switch-intent")
            val tunnelEvents = ktx.di().instance<Tunnel>()
            val wasSwitch = tunnelEvents.enabled()

            if (wasSwitch != switch) {
                tunnelEvents.enabled %= switch
                val msg = if (switch) R.string.notification_keepalive_activating
                else R.string.notification_keepalive_deactivating
                Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()
            }
        } catch (ex: Exception) {
            e("invalid switch app intent", ex)
        }
    }

    override fun isBundleValid(bundle: Bundle) = bundle.containsKey(EVENT_KEY_SWITCH)

}
