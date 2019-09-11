package core.bits

import blocka.BlockaVpnState
import blocka.CurrentAccount
import blocka.CurrentLease
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.MENU_CLICK_BY_NAME
import gs.property.I18n
import gs.property.IWhen
import org.blokada.R
import java.util.*

class VpnStatusVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val s: Tunnel = ktx.di().instance(),
        private val tunnelStatus: EnabledStateActor = ktx.di().instance()
) : ByteVB() {

    override fun attach(view: ByteView) {
        on(BlockaVpnState::class.java, this::update)
        stateListener = s.enabled.doOnUiWhenChanged().then {
            update()
        }
        tunnelStatus.listeners.add(tunnelListener)
        update()
    }

    override fun detach(view: ByteView) {
        cancel(BlockaVpnState::class.java, this::update)
        tunnelStatus.listeners.remove(tunnelListener)
        s.enabled.cancel(stateListener)
    }

    private var active = false
    private var activating = false

    private var stateListener: IWhen? = null

    private fun update() {
        view?.run {
            val account = get(CurrentAccount::class.java)
            val blockaVpnEnabled = get(BlockaVpnState::class.java).enabled
            val lease = get(CurrentLease::class.java)
            when {
                !s.enabled() -> {
                    icon(R.drawable.ic_shield_outline.res())
                    arrow(null)
                    switch(null)
                    label(R.string.home_setup_vpn.res())
                    state(R.string.home_vpn_disabled.res())
                    onTap {
                        //ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                        s.enabled %= true
                        entrypoint.onVpnSwitched(true)
                    }
                }
                blockaVpnEnabled && (activating || !active || !lease.leaseOk) -> {
                    icon(R.drawable.ic_shield_outline.res())
                    arrow(null)
                    switch(null)
                    label(R.string.home_connecting_vpn.res())
                    state(R.string.home_please_wait.res())
                    onTap {}
                    onSwitch {}
                }
                !blockaVpnEnabled && account.activeUntil.after(Date()) -> {
                    icon(R.drawable.ic_shield_outline.res())
                    arrow(null)
                    switch(false)
                    label(R.string.home_setup_vpn.res())
                    state(R.string.home_account_active.res())
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                    }
                    onSwitch {
                        entrypoint.onVpnSwitched(it)
                    }
                }
                !blockaVpnEnabled -> {
                    icon(R.drawable.ic_shield_outline.res())
                    arrow(null)
                    switch(false)
                    label(R.string.home_setup_vpn.res())
                    state(R.string.home_vpn_disabled.res())
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                    }
                    onSwitch {
                        entrypoint.onVpnSwitched(it)
                    }
                }
                else -> {
                    icon(R.drawable.ic_verified.res(), color = R.color.switch_on.res())
                    arrow(null)
                    switch(true)
                    label(lease.gatewayNiceName.res())
                    state(R.string.home_connected_vpn.res())
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
                    }
                    onSwitch {
                        entrypoint.onVpnSwitched(it)
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

}
