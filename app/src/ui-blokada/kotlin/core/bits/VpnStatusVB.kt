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

            arrow(null)
            onTap {
                ktx.emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
            }
            onSwitch { enable ->
                if (enable && !s.enabled()) s.enabled %= true
                entrypoint.onVpnSwitched(enable)
            }

            when {
                !blockaVpnEnabled || !s.enabled() -> {
                    icon(R.drawable.ic_shield_plus_outline.res())
                    switch(false)
                    if (account.activeUntil.after(Date())) label(R.string.home_account_active.res())
                    else label(R.string.home_vpn_disabled.res())
                    state(R.string.home_touch.res())
                }
                else -> {
                    icon(R.drawable.ic_shield_plus.res(), color = R.color.switch_on.res())
                    switch(true)
                    when {
                        activating -> {
                            label(R.string.home_please_wait.res())
                            state(R.string.home_connecting_vpn.res())
                        }
                        !lease.leaseOk -> {
                            label(R.string.home_account_active.res())
                            state(R.string.home_vpn_disabled.res())
                        }
                        else -> {
                            label(lease.gatewayNiceName.res())
                            state(R.string.home_vpn_enabled.res())
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

}
