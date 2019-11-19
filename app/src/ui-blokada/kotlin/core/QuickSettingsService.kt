package core

import android.annotation.TargetApi
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.github.salomonbrys.kodein.instance
import gs.environment.inject
import gs.obsolete.Sync
import org.blokada.R

/**
 *
 */
@TargetApi(24)
class QuickSettingsService : TileService(), IEnabledStateActorListener {

    private val s by lazy { inject().instance<Tunnel>() }
    private val enabledStateActor by lazy { inject().instance<EnabledStateActor>() }
    private var waiting = Sync(false)

    override fun onStartListening() {
        updateTile()
        enabledStateActor.listeners.add(this)
    }

    override fun onStopListening() {
        enabledStateActor.listeners.remove(this)
    }

    override fun onTileAdded() {
        updateTile()
    }

    override fun onClick() {
        if (waiting.get()) return
        s.error %= false
        s.enabled %= !s.enabled()
        updateTile()
    }

    private fun updateTile() {
        if (qsTile == null) return
        if (s.enabled()) {
            qsTile.state = Tile.STATE_ACTIVE
            qsTile.label = getString(R.string.main_status_active_recent)
        } else {
            qsTile.state = Tile.STATE_INACTIVE
            qsTile.label = getString(R.string.main_status_disabled)
        }
        qsTile.updateTile()
    }

    override fun startActivating() {
        waiting.set(true)
        qsTile.label = getString(R.string.main_status_activating)
        qsTile.state = Tile.STATE_ACTIVE
        qsTile.updateTile()
    }

    override fun finishActivating() {
        waiting.set(false)
        qsTile.label = getString(R.string.main_status_active_recent)
        qsTile.state = Tile.STATE_ACTIVE
        qsTile.updateTile()
    }

    override fun startDeactivating() {
        waiting.set(true)
        qsTile.label = getString(R.string.main_status_deactivating)
        qsTile.state = Tile.STATE_INACTIVE
        qsTile.updateTile()
    }

    override fun finishDeactivating() {
        waiting.set(false)
        qsTile.label = getString(R.string.main_status_disabled)
        qsTile.state = Tile.STATE_INACTIVE
        qsTile.updateTile()
    }
}
