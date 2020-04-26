package ui

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.widget.Toast
import blocka.BlockaVpnState
import com.github.salomonbrys.kodein.instance
import com.twofortyfouram.locale.sdk.client.receiver.AbstractPluginSettingReceiver
import core.*
import core.bits.menu.shareLog
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
val EVENT_KEY_SWITCH_DNS = "blokada_switch_dns"
val EVENT_KEY_SWITCH_BLOCKA_VPN = "blokada_switch_blocka_vpn"

class SwitchAppReceiver : AbstractPluginSettingReceiver() {

    override fun isAsync(): Boolean {
        return false
    }

    override fun firePluginSetting(ctx: Context, bundle: Bundle) {
        when {
            bundle.containsKey(EVENT_KEY_SWITCH) -> switchApp(
                ctx,
                bundle.getBoolean(EVENT_KEY_SWITCH)
            )
            bundle.containsKey(EVENT_KEY_SWITCH_BLOCKA_VPN) -> switchBlockaVpn(
                ctx,
                bundle.getBoolean(EVENT_KEY_SWITCH_BLOCKA_VPN)
            )
            bundle.containsKey(EVENT_KEY_SWITCH_DNS) -> switchDns(
                ctx,
                bundle.getBoolean(EVENT_KEY_SWITCH_DNS)
            )
            else -> e("unknown app intent")
        }
    }

    private fun switchApp(ctx: Context, on: Boolean) {
        try {
            v("switching app from intent", on)

            val ktx = ctx.ktx("switch-intent")
            val tunnelEvents = ktx.di().instance<Tunnel>()
            val wasOn = tunnelEvents.enabled()

            if (wasOn != on) {
                tunnelEvents.enabled %= on
                val msg = if (on) R.string.notification_keepalive_activating
                else R.string.notification_keepalive_deactivating
                Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()
            }
        } catch (ex: Exception) {
            e("invalid switch app intent", ex)
        }
    }

    private fun switchDns(ctx: Context, on: Boolean) {
        try {
            v("switching dns from intent", on)

            val ktx = ctx.ktx("switch-intent")
            val dns = ktx.di().instance<Dns>()
            val wasOn = dns.enabled()

            if (wasOn != on) {
                entrypoint.onSwitchDnsEnabled(on)
//                val msg = if (switch) R.string.notification_keepalive_activating
//                else R.string.notification_keepalive_deactivating
//                Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()
            }
        } catch (ex: Exception) {
            e("invalid switch dns intent", ex)
        }
    }

    private fun switchBlockaVpn(ctx: Context, on: Boolean) {
        try {
            v("switching blocka vpn from intent", on)

            val wasOn = get(BlockaVpnState::class.java).enabled

            if (wasOn != on) {
                entrypoint.onVpnSwitched(on)
//                val msg = if (switch) R.string.notification_keepalive_activating
//                else R.string.notification_keepalive_deactivating
//                Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()
            }
        } catch (ex: Exception) {
            e("invalid switch blocka vpn intent", ex)
        }
    }

    override fun isBundleValid(bundle: Bundle) = bundle.containsKey(EVENT_KEY_SWITCH)
            || bundle.containsKey(EVENT_KEY_SWITCH_DNS)
            || bundle.containsKey(EVENT_KEY_SWITCH_BLOCKA_VPN)

}
