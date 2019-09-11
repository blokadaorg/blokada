package core.bits

import com.github.salomonbrys.kodein.instance
import core.*
import gs.property.I18n
import org.blokada.R

class MasterSwitchVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: Tunnel = ktx.di().instance(),
        private val tunnelStatus: EnabledStateActor = ktx.di().instance()
) : ByteVB() {

    private var active = false
    private var activating = false

    override fun attach(view: ByteView) {
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
                    icon(R.drawable.ic_play_arrow.res())
                    label(R.string.home_touch_to_turn_on.res())
                    state(R.string.home_blokada_disabled.res())
                    important(true)
                    onTap {
                        tunnelEvents.enabled %= true
                    }
                }
                else -> {
                    icon(R.drawable.ic_pause.res())
                    label(R.string.home_masterswitch_on.res())
                    state(R.string.home_masterswitch_enabled.res())
                    important(false)
                    onTap {
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
