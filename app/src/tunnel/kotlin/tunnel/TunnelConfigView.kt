package tunnel

import android.content.Context
import android.util.AttributeSet
import android.widget.Button
import android.widget.ScrollView
import android.widget.TextView
import core.ktx
import gs.presentation.SwitchCompatView
import org.blokada.R


class TunnelConfigView(
        ctx: Context,
        attributeSet: AttributeSet
) : ScrollView(ctx, attributeSet) {

    var config = TunnelConfig()
        set(value) {
            field = value
            syncView()
            onNewConfig(value)
        }

    var onRefreshClick = {}
    var onNewConfig = { config: TunnelConfig -> }

    private val refreshButton by lazy { findViewById<Button>(R.id.refresh) }
    private val currentFrequency by lazy { findViewById<TextView>(R.id.frequency_current) }
    private val frequency1Button by lazy { findViewById<Button>(R.id.frequency_1) }
    private val frequency2Button by lazy { findViewById<Button>(R.id.frequency_2) }
    private val frequency3Button by lazy { findViewById<Button>(R.id.frequency_3) }
    private val frequency4Button by lazy { findViewById<Button>(R.id.frequency_4) }
    private val wifiOnlySwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_wifi_only) }
    private val status by lazy { findViewById<TextView>(R.id.status) }

    override fun onFinishInflate() {
        super.onFinishInflate()
        refreshButton.setOnClickListener { onRefreshClick() }
        wifiOnlySwitch.setOnCheckedChangeListener { _, isChecked ->
            config = config.copy(wifiOnly = isChecked) }

        listOf(frequency1Button, frequency2Button, frequency3Button, frequency4Button).forEach {
            it.setOnClickListener { config = config.copy(cacheTTL = idToTtl(it.id)) }
        }

        syncView()

        var capacity = 0
        context.ktx().on(tunnel.Events.MEMORY_CAPACITY) {
            capacity = it
        }

        context.ktx().on(tunnel.Events.RULESET_BUILT, { event ->
            val (deny, allow) = event
            status.text = context.resources.getString(R.string.tunnel_hosts_count, deny - allow) +
                    " / ${capacity}"
        })

        context.ktx().on(tunnel.Events.RULESET_BUILDING, {
            status.text = context.resources.getString(R.string.tunnel_hosts_updating)
        })

        context.ktx().on(tunnel.Events.FILTERS_CHANGING, {
            status.text = context.resources.getString(R.string.tunnel_hosts_downloading)
        })
    }

    private fun syncView() {
        currentFrequency.text = ttlToString(config.cacheTTL)
        wifiOnlySwitch.isChecked = config.wifiOnly
        status.text = context.resources.getString(R.string.tunnel_hosts_count, 0)
    }

    private fun ttlToString(ttl: Long) = when(ttl) {
        259200L -> R.string.tunnel_config_refetch_frequency_2
        604800L -> R.string.tunnel_config_refetch_frequency_3
        2419200L -> R.string.tunnel_config_refetch_frequency_4
        else -> R.string.tunnel_config_refetch_frequency_1
    }.let { context.getString(it) }

    private fun idToTtl(id: Int) = when(id) {
        R.id.frequency_2 -> 259200L
        R.id.frequency_3 -> 604800L
        R.id.frequency_4 -> 2419200L
        else -> 86400L
    }
}
