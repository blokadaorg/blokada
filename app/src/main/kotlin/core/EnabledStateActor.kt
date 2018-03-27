package core

import com.github.salomonbrys.kodein.LazyKodein
import com.github.salomonbrys.kodein.instance

/**
 * Translates internal MainState changes into higher level events used by topbar and fab.
 */
class EnabledStateActor(
        val di: LazyKodein,
        val listeners: MutableList<IEnabledStateActorListener> = mutableListOf()
) {

    // Refs to ensure listeners live only as long as this class
    private val listener1: Any
    private val listener2: Any
    private val listener3: Any

    init {
        val s: Tunnel = di().instance()

        listener1 = s.enabled.doOnUiWhenChanged().then { update(s) }
        listener2 = s.active.doOnUiWhenChanged().then { update(s) }
        listener3 = s.tunnelState.doOnUiWhenChanged().then { update(s) }
        update(s)
    }

    fun update(s: Tunnel) {
        when {
            s.tunnelState(TunnelState.ACTIVATING) -> startActivating()
            s.tunnelState(TunnelState.DEACTIVATING) -> startDeactivating()
            s.tunnelState(TunnelState.ACTIVE) -> finishActivating()
            s.active() -> startActivating()
            else -> finishDeactivating()
        }
    }

    private fun startActivating() {
        try { listeners.forEach { it.startActivating() } } catch (e: Exception) {}
    }

    private fun finishActivating() {
        try { listeners.forEach { it.finishActivating() } } catch (e: Exception) {}
    }

    private fun startDeactivating() {
        try { listeners.forEach { it.startDeactivating() } } catch (e: Exception) {}
    }

    private fun finishDeactivating() {
        try { listeners.forEach { it.finishDeactivating() } } catch (e: Exception) {}
    }
}

interface IEnabledStateActorListener {
    fun startActivating()
    fun finishActivating()
    fun startDeactivating()
    fun finishDeactivating()
}
