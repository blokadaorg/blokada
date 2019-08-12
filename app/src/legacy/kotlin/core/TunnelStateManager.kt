package core

import com.github.michaelbull.result.getOrElse
import com.github.salomonbrys.kodein.instance
import io.paperdb.Book
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
        private val d: Dns = ktx.di().instance(),
        private val loadPersistence: () -> Result<TunnelPause> = Persistence.pause.load,
        private val savePersistence: (TunnelPause) -> Result<Book> = Persistence.pause.save
) {

    private var latest: BlockaConfig = BlockaConfig()
        @Synchronized get
        @Synchronized set

    init {
        ktx.on(BLOCKA_CONFIG) {
            latest = it
            check(it)
        }

        d.enabled.doWhenChanged(withInit = true).then {
            check(latest)
        }

        s.enabled.doWhenChanged(withInit = true).then {
            when {
                !s.enabled() -> {
                    // Save state before pausing
                    savePersistence(TunnelPause(
                            vpn = latest.blockaVpn,
                            adblocking = latest.adblocking,
                            dns = d.enabled()
                    ))

                    ktx.v("pausing features.")
                    ktx.emit(BLOCKA_CONFIG, latest.copy(adblocking = false, blockaVpn = false))
                    d.enabled %= false
                }
                else -> {
                    // Restore the state
                    val pause = loadPersistence().getOrElse {
                        ktx.e("could not load persistence for TunnelPause", it)
                        TunnelPause()
                    }

                    val vpn = pause.vpn && latest.hasGateway() && latest.leaseActiveUntil.after(Date())
                    var adblocking = pause.adblocking && Product.current(ktx.ctx) != Product.DNS
                    var dns = pause.dns

                    ktx.v("restoring features, is (vpn, adblocking, dns): $vpn $adblocking $dns")

                    if (!adblocking && !vpn && !dns) {
                        if (Product.current(ktx.ctx) != Product.DNS) {
                            ktx.v("all features disabled, activating adblocking")
                            adblocking = true
                        } else {
                            ktx.v("all features disabled, activating dns")
                            dns = true
                        }
                    }

                    d.enabled %= dns
                    ktx.emit(BLOCKA_CONFIG, latest.copy(adblocking = adblocking, blockaVpn = vpn))
                }
            }
        }
    }

    private fun check(it: BlockaConfig) {
        when {
            !s.enabled() -> Unit
            !it.adblocking && !it.blockaVpn && !d.enabled() -> {
                ktx.v("turning off because no features enabled")
                s.enabled %= false
            }
            !it.adblocking && it.blockaVpn && !it.hasGateway() -> {
                ktx.v("turning off everything because no gateway selected")
                ktx.emit(BLOCKA_CONFIG, it.copy(blockaVpn = false))
                s.enabled %= false
            }
            (it.adblocking || d.enabled()) && it.blockaVpn && !it.hasGateway() -> {
                ktx.v("turning off vpn because no gateway selected")
                ktx.emit(BLOCKA_CONFIG, it.copy(blockaVpn = false))
            }
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

data class TunnelPause(
        val vpn: Boolean = false,
        val adblocking: Boolean = false,
        val dns: Boolean = false
)

class TunnelPausePersistence {
    val load = { ->
        Result.of { Persistence.paper().read<TunnelPause>("tunnel:pause", TunnelPause()) }
    }
    val save = { pause: TunnelPause ->
        Result.of { Persistence.paper().write("tunnel:pause", pause) }
    }
}
