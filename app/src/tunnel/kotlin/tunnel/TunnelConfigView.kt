package tunnel

import android.content.Context
import android.util.AttributeSet
import android.widget.Button
import android.widget.ScrollView
import android.widget.TextView
import com.github.salomonbrys.kodein.instance
import core.Dns
import core.Format
import core.KeepAlive
import core.ktx
import gs.environment.inject
import gs.presentation.SwitchCompatView
import gs.property.Device
import org.blokada.R
import kotlin.math.max


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

    val watchdogOn by lazy { ctx.inject().instance<Device>().watchdogOn }
    val keepAlive by lazy { ctx.inject().instance<KeepAlive>().keepAlive }
    val autostart by lazy { ctx.inject().instance<core.Tunnel>().startOnBoot }
    val reports by lazy { ctx.inject().instance<Device>().reports }
    val fallback by lazy { ctx.inject().instance<Dns>().fallback }

    var onRefreshClick = {}
    var onNewConfig = { config: TunnelConfig -> }

    private val refreshButton by lazy { findViewById<Button>(R.id.refresh) }
    private val currentFrequency by lazy { findViewById<TextView>(R.id.frequency_current) }
    private val frequency1Button by lazy { findViewById<Button>(R.id.frequency_1) }
    private val frequency2Button by lazy { findViewById<Button>(R.id.frequency_2) }
    private val frequency3Button by lazy { findViewById<Button>(R.id.frequency_3) }
    private val frequency4Button by lazy { findViewById<Button>(R.id.frequency_4) }
    private val wifiOnlySwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_wifi_only) }
    private val watchdogSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_watchdog) }
    private val reportsSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_reports) }
    private val powersaveSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_powersave) }
    private val keepAliveSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_keepalive) }
    private val autoStartSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_autostart) }
    private val fallbackSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_fallback) }
    private val status by lazy { findViewById<TextView>(R.id.status) }

    override fun onFinishInflate() {
        super.onFinishInflate()
        refreshButton.setOnClickListener { onRefreshClick() }
        wifiOnlySwitch.setOnCheckedChangeListener { _, isChecked ->
            config = config.copy(wifiOnly = isChecked) }
        watchdogSwitch.setOnCheckedChangeListener { _, isChecked ->
            watchdogOn %= isChecked }
        reportsSwitch.setOnCheckedChangeListener { _, isChecked ->
            reports %= isChecked }
        powersaveSwitch.setOnCheckedChangeListener { _, isChecked ->
            config = config.copy(powersave = isChecked) }
        keepAliveSwitch.setOnCheckedChangeListener { _, isChecked ->
            keepAlive %= isChecked }
        autoStartSwitch.setOnCheckedChangeListener { _, isChecked ->
            autostart %= isChecked }
        fallbackSwitch.setOnCheckedChangeListener { _, isChecked ->
            fallback %= isChecked }

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
            status.text = "%s\n%s".format(
                    context.resources.getString(R.string.tunnel_hosts_count2,
                            Format.counter(max(deny - allow, 0))),
                    context.resources.getString(R.string.tunnel_config_memory_capacity,
                            Format.counter(capacity + deny, round = true))
            )
        })

        context.ktx().on(tunnel.Events.RULESET_BUILDING, {
            status.text = context.resources.getString(R.string.tunnel_hosts_updating)
        })

        context.ktx().on(tunnel.Events.FILTERS_CHANGING, {
            status.text = context.resources.getString(R.string.tunnel_hosts_downloading)
        })

        watchdogOn.doOnUiWhenSet().then {
            watchdogSwitch.isChecked = watchdogOn()
        }

        reports.doOnUiWhenSet().then {
            reportsSwitch.isChecked = reports()
        }

        autostart.doOnUiWhenSet().then {
            autoStartSwitch.isChecked = autostart()
        }

        keepAlive.doOnUiWhenSet().then {
            keepAliveSwitch.isChecked = keepAlive()
        }

        fallback.doOnUiWhenSet().then {
            fallbackSwitch.isChecked = fallback()
        }
    }

    private fun syncView() {
        currentFrequency.text = ttlToString(config.cacheTTL)
        wifiOnlySwitch.isChecked = config.wifiOnly
        status.text = context.resources.getString(R.string.tunnel_hosts_count2, 0.toString())
        watchdogSwitch.isChecked = watchdogOn()
        reportsSwitch.isChecked = reports()
        powersaveSwitch.isChecked = config.powersave
        fallbackSwitch.isChecked = fallback()
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
