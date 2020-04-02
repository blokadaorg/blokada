package core.bits

import blocka.BlockaVpnState
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.MENU_CLICK_BY_NAME
import gs.property.I18n
import gs.property.IWhen
import org.blokada.R
import tunnel.ExtendedRequestLog
import tunnel.RequestUpdate
import tunnel.TunnelConfig
import tunnel.TunnelEvents

class AdsBlockedVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: Tunnel = ktx.di().instance(),
        private val tunnelStatus: EnabledStateActor = ktx.di().instance()
) : ByteVB() {

    private var onDropped = { update: RequestUpdate ->
            if (update.oldState == null) {
                dropped = ExtendedRequestLog.dropCount
                update()
            }
        }
    private var dropped: Int = 0
    private var active = false
    private var activating = false

    override fun attach(view: ByteView) {
        ktx.on(TunnelEvents.REQUEST_UPDATE, onDropped)
        tunnelStatus.listeners.add(tunnelListener)
        tunnelStatus.update(tunnelEvents)
        on(TunnelConfig::class.java, this::update)
        on(BlockaVpnState::class.java, this::update)
        update()
    }

    override fun detach(view: ByteView) {
        ktx.cancel(TunnelEvents.REQUEST_UPDATE, onDropped)
        tunnelStatus.listeners.remove(tunnelListener)
        cancel(TunnelConfig::class.java, this::update)
        cancel(BlockaVpnState::class.java, this::update)
    }

    private fun update() {
        val config = get(TunnelConfig::class.java)

        view?.run {
            arrow(null)
            onTap {
                ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_ads.res())
            }
            onSwitch { enable ->
                if (enable && !tunnelEvents.enabled()) tunnelEvents.enabled %= true
                entrypoint.onSwitchAdblocking(enable)
            }

            val droppedString = i18n.getString(R.string.home_requests_blocked, Format.counter(dropped))

            when {
                !config.adblocking || !tunnelEvents.enabled() -> {
                    icon(R.drawable.ic_show.res())
                    label(R.string.home_adblocking_disabled.res())
                    state(R.string.home_touch.res())
                    switch(false)
                }
                else -> {
                    icon(R.drawable.ic_blocked.res(), color = R.color.switch_on.res())
                    label(droppedString.res())
                    state(R.string.home_adblocking_enabled.res())
                    switch(true)
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
