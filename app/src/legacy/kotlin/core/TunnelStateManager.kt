package core

import com.github.salomonbrys.kodein.instance
import org.blokada.R
import tunnel.BLOCKA_CONFIG
import tunnel.BlockaConfig
import tunnel.showSnack
import java.util.*

/**
 * Automatically decides on the state of Tunnel.enabled flag based on the
 * state of adblocking, vpn, and DNS.
 */
class TunnelStateManager(
        private val ktx: AndroidKontext,
        private val s: Tunnel = ktx.di().instance(),
        private val d: Dns = ktx.di().instance()
) {

    private var latest: BlockaConfig = BlockaConfig()

    init {
        ktx.on(BLOCKA_CONFIG) {
            latest = it
            check(it)
        }

        d.enabled.doWhenChanged(withInit = true).then {
            check(latest)
        }

        s.enabled.doWhenChanged(withInit = true).then {
            if (s.enabled() && !latest.adblocking && !latest.blockaVpn && !d.enabled()) {
                // Everything is off, turn on
                val vpn = latest.hasGateway() && latest.leaseActiveUntil.after(Date())
                val adblocking = Product.current(ktx.ctx) != Product.DNS

                ktx.emit(BLOCKA_CONFIG, latest.copy(adblocking = adblocking, blockaVpn = vpn))
            }
        }
    }

    private fun check(it: BlockaConfig) {
        when {
            !it.adblocking && !it.blockaVpn && !d.enabled() -> s.enabled %= false
            !it.adblocking && it.blockaVpn && !it.hasGateway() -> {
                ktx.emit(BLOCKA_CONFIG, it.copy(blockaVpn = false))
                s.enabled %= false
            }
            (it.adblocking || d.enabled()) && it.blockaVpn && !it.hasGateway() -> {
                ktx.emit(BLOCKA_CONFIG, it.copy(blockaVpn = false))
            }
            !s.enabled() -> s.enabled %= true
        }
    }

    fun turnAdblocking(on: Boolean): Boolean {
        ktx.emit(BLOCKA_CONFIG, latest.copy(adblocking = on))
        return true
    }

    fun turnVpn(on: Boolean): Boolean {
        return when {
            !on -> {
                ktx.emit(BLOCKA_CONFIG, latest.copy(blockaVpn = false))
                true
            }
            latest.activeUntil.before(Date()) -> {
                showSnack(R.string.menu_vpn_activate_account.res())
                ktx.emit(BLOCKA_CONFIG, latest.copy(blockaVpn = false))
                false
            }
            !latest.hasGateway() -> {
                showSnack(R.string.menu_vpn_select_gateway.res())
                ktx.emit(BLOCKA_CONFIG, latest.copy(blockaVpn = false))
                false
            }
            else -> {
                ktx.emit(BLOCKA_CONFIG, latest.copy(blockaVpn = true))
                true
            }
        }
    }
}

