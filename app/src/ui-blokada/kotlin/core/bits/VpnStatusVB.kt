package core.bits

import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.MENU_CLICK_BY_NAME
import gs.property.I18n
import gs.property.IWhen
import org.blokada.R
import tunnel.BLOCKA_CONFIG
import tunnel.BlockaConfig
import java.util.*

class VpnStatusVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val s: Tunnel = ktx.di().instance(),
        private val tunnelStatus: EnabledStateActor = ktx.di().instance(),
        private val tunManager: TunnelStateManager = ktx.di().instance()
) : ByteVB() {

    override fun attach(view: ByteView) {
        ktx.on(BLOCKA_CONFIG, configListener)
        stateListener = s.enabled.doOnUiWhenChanged().then {
            update()
        }
        tunnelStatus.listeners.add(tunnelListener)
        update()
    }

    override fun detach(view: ByteView) {
        ktx.cancel(BLOCKA_CONFIG, configListener)
        tunnelStatus.listeners.remove(tunnelListener)
        s.enabled.cancel(stateListener)
    }

    private var wasActive = false
    private var active = false
    private var activating = false
    private var config: BlockaConfig = BlockaConfig()
    private val configListener = { cfg: BlockaConfig ->
        config = cfg
        update()
        activateVpnAutomatically(cfg)
        wasActive = cfg.activeUntil.after(Date())
        Unit
    }

    private var stateListener: IWhen? = null

    private val update = { ->
        view?.run {
            when {
                !s.enabled() -> {
                    icon(R.drawable.ic_shield_outline.res())
                    arrow(null)
                    switch(false)
                    label(R.string.home_setup_vpn.res())
                    state(R.string.home_vpn_disabled.res())
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                    }
                    onSwitch {
                        if (!tunManager.turnVpn(it)) {
                            ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                        }
                    }
                }
                config.blockaVpn && (activating || !active) -> {
                    icon(R.drawable.ic_shield_outline.res())
                    arrow(null)
                    switch(null)
                    label(R.string.home_connecting_vpn.res())
                    state(R.string.home_please_wait.res())
                    onTap {}
                    onSwitch {}
                }
                !config.blockaVpn && config.activeUntil.after(Date()) -> {
                    icon(R.drawable.ic_shield_outline.res())
                    arrow(null)
                    switch(false)
                    label(R.string.home_setup_vpn.res())
                    state(R.string.home_account_active.res())
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                    }
                    onSwitch {
                        if (!tunManager.turnVpn(it)) {
                            ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                        }
                    }
                }
                !config.blockaVpn -> {
                    icon(R.drawable.ic_shield_outline.res())
                    arrow(null)
                    switch(false)
                    label(R.string.home_setup_vpn.res())
                    state(R.string.home_vpn_disabled.res())
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                    }
                    onSwitch {
                        if (!tunManager.turnVpn(it)) {
                            ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                        }
                    }
                }
                else -> {
                    icon(R.drawable.ic_verified.res(), color = R.color.switch_on.res())
                    arrow(null)
                    switch(true)
                    label(config.gatewayNiceName.res())
                    state(R.string.home_connected_vpn.res())
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                    }
                    onSwitch {
                        if (!tunManager.turnVpn(it)) {
                            ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                        }
                    }
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

    private fun activateVpnAutomatically(cfg: BlockaConfig) {
        if (!cfg.blockaVpn && !wasActive && cfg.activeUntil.after(Date()) && cfg.hasGateway()) {
            ktx.v("automatically enabling vpn on new subscription")
            ktx.emit(BLOCKA_CONFIG, cfg.copy(blockaVpn = true))
        }
    }

}
