package adblocker

import android.content.Context
import android.view.LayoutInflater
import android.view.ViewGroup
import com.github.salomonbrys.kodein.instance
import core.Dash
import core.Filters
import core.Tunnel
import core.ktx
import gs.environment.inject
import org.blokada.R
import tunnel.TunnelConfigView

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
        val d: gs.property.Device = ctx.inject().instance(),
        val t: tunnel.Main = ctx.inject().instance()
) : Dash(DASH_ID_HOSTS_COUNT,
        R.drawable.ic_counter,
        hasView = true
) {

    init {
        text = ctx.resources.getString(R.string.tunnel_hosts_count, 0)

        ctx.ktx().on(tunnel.Events.RULESET_BUILT, { event ->
            val (deny, allow) = event
            text = ctx.resources.getString(R.string.tunnel_hosts_count, deny - allow)
        })

        ctx.ktx().on(tunnel.Events.RULESET_BUILDING, {
            text = ctx.resources.getString(R.string.tunnel_hosts_updating)
        })

        ctx.ktx().on(tunnel.Events.FILTERS_CHANGING, {
            text = ctx.resources.getString(R.string.tunnel_hosts_downloading)
        })
    }

    override fun createView(parent: Any): Any? {
        return createConfigView(parent as ViewGroup)
    }

    private var configView: TunnelConfigView? = null

    private fun createConfigView(parent: ViewGroup): TunnelConfigView {
        val ctx = parent.context
        configView = LayoutInflater.from(ctx).inflate(R.layout.view_tunnel_config, parent, false) as TunnelConfigView
        configView?.onRefreshClick = {
            t.invalidateFilters("tunnelDash:config:refresh".ktx())
        }
        configView?.onNewConfig = {
            tunnel.Persistence.config.save(it)
            t.reloadConfig(ctx.ktx("tunnelDassh:config:new"), d.onWifi())
        }
        configView?.config = tunnel.Persistence.config.load("tunnelDash:config:load".ktx())
        return configView!!
    }
}

