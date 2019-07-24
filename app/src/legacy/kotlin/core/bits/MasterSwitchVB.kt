package core.bits

import com.github.salomonbrys.kodein.instance
import core.*
import gs.property.I18n
import org.blokada.R

class MasterSwitchVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: Tunnel = ktx.di().instance(),
        private val tunnelStatus: EnabledStateActor = ktx.di().instance(),
        private val tunManager: TunnelStateManager = ktx.di().instance()
) : ByteVB() {

    private var active = false
    private var activating = false

    override fun attach(view: ByteView) {
        view.important(true)
        tunnelStatus.listeners.add(tunnelListener)
        tunnelStatus.update(tunnelEvents)
        update()
    }

    override fun detach(view: ByteView) {
        tunnelStatus.listeners.remove(tunnelListener)
    }

    private val update = {
        view?.run {
            when {
                !tunnelEvents.enabled() -> {
                    icon(R.drawable.ic_power.res())
                    label(R.string.home_touch_to_turn_on.res())
                    state(R.string.home_blokada_disabled.res())
                    switch(false)
                    onTap {
                        ktx.emit(OPEN_MENU)
                    }
                    onSwitch {
                        tunnelEvents.enabled %= true
                    }
                }
                activating || !active -> {
                    icon(R.drawable.ic_power.res())
                    label(R.string.home_activating.res())
                    state(R.string.home_please_wait.res())
                    switch(null)
                    onTap { }
                    onSwitch {  }
                }
                else -> {
                    icon(R.drawable.ic_power.res(), color = R.color.switch_on.res())
                    label(R.string.home_masterswitch_on.res())
                    switch(true)
                    state(R.string.home_masterswitch_enabled.res())
                    onTap {
                        ktx.emit(OPEN_MENU)
                    }
                    onSwitch {
                        tunnelEvents.enabled %= false
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
