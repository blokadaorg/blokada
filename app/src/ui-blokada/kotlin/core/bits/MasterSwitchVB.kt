package core.bits

import blocka.BlockaVpnState
import com.github.salomonbrys.kodein.instance
import core.*
import gs.property.I18n
import org.blokada.R
import tunnel.TunnelConfig

class MasterSwitchVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: Tunnel = ktx.di().instance(),
        private val tunnelStatus: EnabledStateActor = ktx.di().instance()
) : core.MasterSwitchVB() {

    private var active = false
    private var activating = false

    override fun attach(view: MasterSwitchView) {
        tunnelStatus.listeners.add(tunnelListener)
        tunnelStatus.update(tunnelEvents)
        update()
    }

    override fun detach(view: MasterSwitchView) {
        tunnelStatus.listeners.remove(tunnelListener)
    }

    private val update = {
        val config = get(TunnelConfig::class.java)
        val blockaVpnEnabled = get(BlockaVpnState::class.java).enabled

        view?.run {
            onSwitch { enable ->
                tunnelEvents.enabled %= enable
            }

            switch(tunnelEvents.enabled())
            onTap {
                tunnelEvents.enabled %= !tunnelEvents.enabled()
            }

            when {
                !tunnelEvents.enabled() -> {
                    state("Blokada is deactivated, and your Internet is not protected.".res())
                    line(0)
                }
                activating -> {
                    state(R.string.home_please_wait.res())
                    line(1)
                }
                !tunnelEvents.active() -> {
                    state(R.string.home_masterswitch_waiting.res())
                    line(1)
                }
                !config.adblocking && !blockaVpnEnabled -> {
                    state(R.string.home_dns_only.res())
                    line(2)
                }
                !config.adblocking -> {
                    state(R.string.home_vpn_only.res())
                    line(3)
                }
                !blockaVpnEnabled -> {
                    state("Blokada is active.".res())
                    line(2)
                }
                else -> {
                    state("BLOKADA+ is active, and your Internet is protected.".res())
                    line(3)
                }
           }
        }
        Unit
    }

    private val tunnelListener = object : IEnabledStateActorListener {
        override fun startActivating() {
            activating = true
            active = false
            update()
        }

        override fun finishActivating() {
            activating = false
            active = true
            update()
        }

        override fun startDeactivating() {
            activating = true
            active = false
            update()
        }

        override fun finishDeactivating() {
            activating = false
            active = false
            update()
        }
    }

}
