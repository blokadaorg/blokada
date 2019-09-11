package core.bits

import blocka.BlockaVpnState
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.MENU_CLICK_BY_NAME
import gs.property.I18n
import gs.property.IWhen
import org.blokada.R
import tunnel.TunnelConfig

class AdsBlockedVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: Tunnel = ktx.di().instance(),
        private val tunnelStatus: EnabledStateActor = ktx.di().instance()
) : ByteVB() {

    private var droppedCountListener: IWhen? = null
    private var dropped: Int = 0
    private var active = false
    private var activating = false

    override fun attach(view: ByteView) {
        droppedCountListener = tunnelEvents.tunnelDropCount.doOnUiWhenSet().then {
            dropped = tunnelEvents.tunnelDropCount()
            update()
        }
        tunnelStatus.listeners.add(tunnelListener)
        tunnelStatus.update(tunnelEvents)
        on(TunnelConfig::class.java, this::update)
        on(BlockaVpnState::class.java, this::update)
        update()
    }

    override fun detach(view: ByteView) {
        tunnelEvents.tunnelDropCount.cancel(droppedCountListener)
        tunnelStatus.listeners.remove(tunnelListener)
        cancel(TunnelConfig::class.java, this::update)
        cancel(BlockaVpnState::class.java, this::update)
    }

    private fun update() {
        val config = get(TunnelConfig::class.java)
        val blockaVpnState = get(BlockaVpnState::class.java)

        view?.run {
            when {
                !tunnelEvents.enabled() -> {
                    icon(R.drawable.ic_show.res())
                    label(R.string.home_touch_adblocking.res())
                    state(R.string.home_adblocking_disabled.res())
                    switch(null)
                    arrow(null)
                    onTap {
                        tunnelEvents.enabled %= true
                        entrypoint.onSwitchAdblocking(true)
                    }
                }
                activating || !active -> {
                    icon(R.drawable.ic_show.res())
                    label(R.string.home_activating.res())
                    state(R.string.home_please_wait.res())
                    switch(null)
                    arrow(null)
                    onTap { }
                    onSwitch {  }
                }
                !config.adblocking && blockaVpnState.enabled -> {
                    icon(R.drawable.ic_show.res())
                    label(R.string.home_vpn_only.res())
                    state(R.string.home_adblocking_disabled.res())
                    switch(false)
                    arrow(null)
                    onTap {
                    }
                    onSwitch {
                        entrypoint.onSwitchAdblocking(true)
                    }
                }
                !config.adblocking -> {
                    icon(R.drawable.ic_show.res())
                    label(R.string.home_dns_only.res())
                    state(R.string.home_adblocking_disabled.res())
                    switch(false)
                    arrow(null)
                    onTap {
                    }
                    onSwitch {
                        entrypoint.onSwitchAdblocking(true)
                    }
                }
                else -> {
                    val droppedString = i18n.getString(R.string.home_requests_blocked, Format.counter(dropped))
                    icon(R.drawable.ic_blocked.res(), color = R.color.switch_on.res())
                    label(droppedString.res())
                    switch(true)
                    arrow(null)
                    state(R.string.home_adblocking_enabled.res())
                    onTap {
//                        ktx.emit(SWIPE_RIGHT)
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_ads.res())
                    }
                    onSwitch {
                        entrypoint.onSwitchAdblocking(it)
                    }
                }
           }
        }
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
