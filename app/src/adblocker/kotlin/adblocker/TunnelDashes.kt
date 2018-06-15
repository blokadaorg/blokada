package adblocker

import android.content.Context
import com.github.salomonbrys.kodein.instance
import core.*
import gs.environment.inject
import kotlinx.coroutines.experimental.android.UI
import kotlinx.coroutines.experimental.channels.consumeEach
import kotlinx.coroutines.experimental.launch
import org.blokada.R

val DASH_ID_HOSTS_COUNT = "tunnel_hosts"

class TunnelDashCountDropped(
        val ctx: Context,
        val t: Tunnel = ctx.inject().instance()
) : Dash("tunnel_drop",
        R.drawable.ic_block,
        ctx.getString(R.string.tunnel_dropped_count_desc),
        onLongClick = { t.tunnelDropCount %= 0; true }
) {

    private val listener: Any
    init {
        text = getBlockedString(0)
        listener = t.tunnelDropCount.doOnUiWhenSet().then {
            text = getBlockedString(t.tunnelDropCount())
        } // TODO: think item lifetime vs listener leak
    }

    private fun getBlockedString(blocked: Int): String {
        return ctx.resources.getString(R.string.tunnel_dropped_count, blocked)
    }
}

class TunnelDashHostsCount(
        val ctx: Context,
        val s: Filters = ctx.inject().instance(),
        val cmd: Commands = ctx.inject().instance()
) : Dash(DASH_ID_HOSTS_COUNT,
        R.drawable.ic_counter,
        ctx.getBrandedString(R.string.tunnel_hosts_desc),
        onClick = { cmd.send(SyncFilters()); cmd.send(SyncHostsCache()); true }
) {

    init {
        launch {
            val request = MonitorHostsCount()
            cmd.subscribe(request).consumeEach {
                launch(UI) { text = getCountString(it) }
            }
        }
    }

    private fun getCountString(count: Int): String {
        return if (count >= 0) ctx.resources.getString(R.string.tunnel_hosts_count, count)
        else ctx.resources.getString(R.string.tunnel_hosts_updating)
    }
}

