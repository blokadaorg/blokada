package core

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.widget.EditText
import androidx.core.content.FileProvider
import com.github.salomonbrys.kodein.instance
import filter.hostnameRegex
import filter.id
import filter.sourceToIcon
import filter.sourceToName
import gs.environment.ComponentProvider
import gs.property.*
import kotlinx.android.synthetic.adblockerHome.slotview_content.view.*
import kotlinx.coroutines.experimental.async
import org.blokada.R
import tunnel.*
import tunnel.Filter
import update.UpdateCoordinator
import update.isUpdate
import java.io.File
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class ProtectionVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: EnabledStateActor = ktx.di().instance(),
        private val s: Tunnel = ktx.di().instance(),
        private val d: Dns = ktx.di().instance(),
        private val device: Device = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var active = false
    private var activating = false
    private var error = false
    private var connected = true
    private var vpn = 0
    private var adblocking = 0
    private var startOnBoot = 0
    private var battery = 1
    private var dns = 1

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

    private var onStartOnBoot: IWhen? = null
    private var onError: IWhen? = null
    private var onDns: IWhen? = null
    private var onConnected: IWhen? = null

    override fun attach(view: SlotView) {
        tunnelEvents.listeners.add(tunnelListener)
        tunnelEvents.update(s)
        ktx.on(BLOCKA_CONFIG, configListener)
        onStartOnBoot = s.startOnBoot.doOnUiWhenSet().then {
            startOnBoot = if (s.startOnBoot()) 1 else 0
            update()
        }
        onDns = d.dnsServers.doOnUiWhenSet().then {
            dns = if (hasGoodDnsServers(d)) 1 else 0
            update()
        }
        onError = s.error.doOnUiWhenSet().then {
            error = s.error()
            update()
        }
        onConnected = device.connected.doOnUiWhenSet().then {
            connected = device.connected()
            update()
        }
    }

    override fun detach(view: SlotView) {
        tunnelEvents.listeners.remove(tunnelListener)
        ktx.cancel(BLOCKA_CONFIG, configListener)
        s.startOnBoot.cancel(onStartOnBoot)
        d.dnsServers.cancel(onDns)
        s.error.cancel(onError)
        device.connected.cancel(onConnected)
    }

    private val configListener = { cfg: BlockaConfig ->
        vpn = if (cfg.blockaVpn) 1 else 0
        adblocking = if (cfg.adblocking) 1 else 0
        update()
        Unit
    }

    private fun update() {
        if (activating) {
            activating()
            return
        } else if (!connected) {
            disconnected()
            return
        } else if (error) {
            error()
            return
        } else if (!active) {
            off()
            return
        }

        val max = 5
        val score = when {
            vpn == 1 && startOnBoot == 1 && battery == 1 /*&& dns == 1*/ -> {
                // Show full score so users with VPN or but no adblocking are happy
                max
            }
            else -> vpn + adblocking + startOnBoot + battery + dns
        }

        val description = when {
            startOnBoot == 0 -> R.string.slot_protection_no_start_on_boot
            vpn == 0 -> R.string.slot_protection_no_vpn
            adblocking == 0 -> R.string.slot_protection_no_adblocking
            battery == 0 -> R.string.slot_protection_no_battery_whitelist
//            dns == 0 -> R.string.slot_protection_no_dns
            else -> R.string.slot_protection_ok
        }

        // Never show 0, it's reserved when the app is off
        score(if (score == 0) 1 else score, max, description)
    }

    private val settingsAction = Slot.Action(i18n.getString(R.string.slot_protection_action), {
        ktx.emit(OPEN_MENU)
    })

    private fun off() {
        view?.content = Slot.Content(
                label = i18n.getString(R.string.slot_protection_off),
                icon = ktx.ctx.getDrawable(R.drawable.ic_shield_outline),
                description = i18n.getString(R.string.slot_protection_off_desc),
                color = ktx.ctx.resources.getColor(R.color.colorProtectionLow),
                info = i18n.getString(R.string.slot_status_info),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_activate), {
                    s.enabled %= true
                    s.error %= false
                }),
                action2 = settingsAction
        )
        view?.type = Slot.Type.PROTECTION_OFF
    }

    private fun error() {
        view?.content = Slot.Content(
                label = i18n.getString(R.string.slot_protection_error),
                description = i18n.getString(R.string.slot_protection_error_desc),
                icon = ktx.ctx.getDrawable(R.drawable.ic_shield_outline),
                color = ktx.ctx.resources.getColor(R.color.colorProtectionLow),
                info = i18n.getString(R.string.slot_status_info),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_activate), {
                    s.error %= false
                    s.enabled %= true
                }),
                action2 = settingsAction
        )
        view?.type = Slot.Type.PROTECTION_OFF
    }

    private fun disconnected() {
        view?.content = Slot.Content(
                label = i18n.getString(R.string.slot_protection_disconnected),
                description = i18n.getString(R.string.slot_protection_disconnected_desc),
                icon = ktx.ctx.getDrawable(R.drawable.ic_shield_outline),
                color = ktx.ctx.resources.getColor(R.color.colorProtectionMedium),
                info = i18n.getString(R.string.slot_status_info)
        )
        view?.type = Slot.Type.PROTECTION
    }


    private fun activating() {
        view?.content = Slot.Content(
                label = i18n.getString(R.string.slot_protection_activating),
                icon = ktx.ctx.getDrawable(R.drawable.ic_shield_outline),
                info = i18n.getString(R.string.slot_status_info),
                color = ktx.ctx.resources.getColor(R.color.colorProtectionMedium),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_deactivate), {
                    s.enabled %= false
                })
        )
        view?.type = Slot.Type.PROTECTION
    }

    private fun score(score: Int, max: Int, description: Int) {
        val color = if (score < max / 2) R.color.colorProtectionMedium
        else R.color.colorProtectionHigh

        val icon = when (score) {
            max -> R.drawable.ic_verified
            0 -> R.drawable.ic_shield_outline
            else -> R.drawable.ic_shield_key_outline
        }

        val label = when (score) {
            max -> R.string.slot_protection_active
            else -> R.string.slot_protection_active_warning
        }

        view?.content = Slot.Content(
                label = i18n.getString(label),
                header = i18n.getString(R.string.slot_protection_header),
                info = i18n.getString(R.string.slot_status_info),
                description = "%s<br/><br/>%s".format(i18n.getString(description), i18n.getString(R.string.slot_protection_description)),
                icon = ktx.ctx.getDrawable(icon),
                color = ktx.ctx.resources.getColor(color),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_deactivate), {
                    s.enabled %= false
                }),
                action2 = settingsAction
        )
        view?.type = Slot.Type.PROTECTION
    }
}

class AppStatusVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: EnabledStateActor = ktx.di().instance(),
        private val tunnelEvents2: Tunnel = ktx.di().instance(),
        private val s: Tunnel = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var dropped: Int = 0
    private var config: BlockaConfig = BlockaConfig()

    private val actionTurnOn = Slot.Action(i18n.getString(R.string.slot_action_activate_adblocking)) {
        ktx.emit(BLOCKA_CONFIG, config.copy(adblocking = true))
    }

    private val actionTurnOff = Slot.Action(i18n.getString(R.string.slot_action_deactivate_adblocking)) {
        ktx.emit(BLOCKA_CONFIG, config.copy(adblocking = false))
    }

    private val update = {
        view?.apply {
            val droppedString = i18n.getString(R.string.tunnel_dropped_count2,
                    Format.counter(tunnelEvents2.tunnelDropCount()))
            val t: Tunnel = ktx.di().instance()
            content = Slot.Content(
                    icon = ktx.ctx.getDrawable(R.drawable.ic_block),
                    label = droppedString,
                    header = droppedString,
                    description = if (config.adblocking)
                        i18n.getString(R.string.slot_status_description_active)
                    else i18n.getString(R.string.slot_status_description_inactive),
                    detail = Format.date(Date()),
                    action1 = Slot.Action(i18n.getString(R.string.slot_action_share)) {
                        val shareIntent: Intent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, getMessage(ktx.ctx, t.tunnelDropStart(), t.tunnelDropCount()))
                            type = "text/plain"
                        }
                        ktx.ctx.startActivity(Intent.createChooser(shareIntent,
                                ktx.ctx.getText(R.string.slot_dropped_share_title)))
                    },
                    action2 = if (config.adblocking) actionTurnOff else actionTurnOn,
                    action3 = Slot.Action(i18n.getString(R.string.slot_dropped_action_clear)) {
                        tunnelEvents2.tunnelDropCount %= 0
                    }
            )
        }
        Unit
    }

    private val configListener = { cfg: BlockaConfig ->
        config = cfg
        update()
        Unit
    }

    fun getMessage(ctx: Context, timeStamp: Long, dropCount: Int): String {
        var elapsed: Long = System.currentTimeMillis() - timeStamp
        elapsed /= 60000
        if(elapsed < 120) {
            return ctx.resources.getString(R.string.social_share_bodym, dropCount, elapsed)
        }
        elapsed /= 60
        if(elapsed < 48) {
            return ctx.resources.getString(R.string.social_share_bodyh, dropCount, elapsed)
        }
        elapsed /= 24
        if(elapsed < 28) {
            return ctx.resources.getString(R.string.social_share_bodyd, dropCount, elapsed)
        }
        elapsed /= 7
        return ctx.resources.getString(R.string.social_share_bodyw, dropCount, elapsed)
    }

    private var droppedCountListener: IWhen? = null

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        droppedCountListener = tunnelEvents2.tunnelDropCount.doOnUiWhenSet().then {
            dropped = tunnelEvents2.tunnelDropCount()
            update()
        }
        ktx.on(BLOCKA_CONFIG, configListener)
    }

    override fun detach(view: SlotView) {
        tunnelEvents2.tunnelDropCount.cancel(droppedCountListener)
        ktx.cancel(BLOCKA_CONFIG, configListener)
    }

}

class VpnStatusVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val s: Tunnel = ktx.di().instance(),
        private val modal: ModalManager = modalManager,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var config: BlockaConfig = BlockaConfig()

    private val update = { ->
        view?.apply {
            val connected = s.enabled() && config.blockaVpn
            content = Slot.Content(
                    icon = ktx.ctx.getDrawable(R.drawable.ic_shield_key_outline),
                    label = if (connected)
                        i18n.getString(R.string.slot_status_vpn_turned_on, config.gatewayNiceName)
                    else i18n.getString(R.string.slot_status_vpn_turned_off),
                    description = if (connected) {
                        i18n.getString(R.string.slot_status_vpn_desc_on, config.gatewayIp)
                    } else i18n.getString(R.string.slot_status_vpn_desc_off),
                    detail = Format.date(Date()),
//                    action1 = Slot.Action(i18n.getString(
//                            if (config.blockaVpn) R.string.slot_status_vpn_turn_off
//                            else R.string.slot_status_vpn_turn_on
//                    )) {
//                        if (config.activeUntil.before(Date())) {
//                            modal.openModal()
//                            ktx.ctx.startActivity(Intent(ktx.ctx, SubscriptionActivity::class.java))
//                        } else {
//                            Toast.makeText(ktx.ctx, i18n.getString(
//                                    if (config.blockaVpn) R.string.slot_status_vpn_turned_off
//                                    else R.string.slot_status_vpn_connecting
//                            ), Toast.LENGTH_LONG).show()
//
//                            if (config.blockaVpn) clearConnectedGateway(ktx, config, showError = false)
//                            else {
//                                val newCfg = config.copy(blockaVpn = !config.blockaVpn)
//                                checkAccountInfo(ktx, newCfg)
//                            }
//                        }
//                    },
                    action1 = Slot.Action(i18n.getString(R.string.slot_status_vpn_lease)) {
                        async {
                            checkAccountInfo(ktx, config!!)
                        }
                    }
            )
            date = Date()
        }
        Unit
    }

    private var wasActive = false
    private val configListener = { cfg: BlockaConfig ->
        config = cfg
        update()
        activateVpnAutomatically(cfg)
        wasActive = cfg.activeUntil.after(Date())
        Unit
    }

    private var stateListener: IWhen? = null

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        ktx.on(BLOCKA_CONFIG, configListener)
        stateListener = s.enabled.doOnUiWhenChanged().then {
            update()
        }
    }

    override fun detach(view: SlotView) {
        ktx.cancel(BLOCKA_CONFIG, configListener)
        s.enabled.cancel(stateListener)
    }

    private fun activateVpnAutomatically(cfg: BlockaConfig) {
        if (!cfg.blockaVpn && !wasActive && cfg.activeUntil.after(Date()) && cfg.hasGateway()) {
            ktx.v("automatically enabling vpn on new subscription")
            ktx.emit(BLOCKA_CONFIG, cfg.copy(blockaVpn = true))
        }
    }
}

class FiltersStatusVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var rules: Int = 0
    private var memory: Int = 0

    private val updatingFilters = {
        view?.apply {
            type = Slot.Type.INFO
            val message = i18n.getString(R.string.panel_ruleset_updating)
            content = Slot.Content(
                    label = message,
                    header = i18n.getString(R.string.panel_ruleset),
                    description = message
            )
            date = Date()
        }
        Unit
    }

    private val refreshRuleset = { it: Pair<Int, Int> ->
        rules = it.first
        refresh()
        Unit
    }

    private val refreshMemory = { it: Int ->
        memory = it
        refresh()
        Unit
    }

    private fun refresh() {
        view?.apply {
            type = Slot.Type.COUNTER
            content = Slot.Content(
                    label = i18n.getString(R.string.panel_ruleset_title, Format.counter(rules)),
                    header = i18n.getString(R.string.panel_ruleset),
                    description = i18n.getString(R.string.panel_ruleset_built,
                            Format.counter(rules), Format.counter(memory, round = true))
            )
            date = Date()
        }
    }

    override fun attach(view: SlotView) {
        ktx.on(Events.RULESET_BUILT, refreshRuleset)
        ktx.on(Events.FILTERS_CHANGING, updatingFilters)
        ktx.on(Events.MEMORY_CAPACITY, refreshMemory)
    }

    override fun detach(view: SlotView) {
        ktx.cancel(Events.RULESET_BUILT, refreshRuleset)
        ktx.cancel(Events.FILTERS_CHANGING, updatingFilters)
        ktx.cancel(Events.MEMORY_CAPACITY, refreshMemory)
    }

}

class DomainForwarderVB(
        private val domain: String,
        private val date: Date,
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelManager: tunnel.Main = ktx.di().instance(),
        private val alternative: Boolean = false,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.FORWARD
        view.date = date
        view.content = Slot.Content(
                label = i18n.getString(R.string.panel_domain_forwarded, domain),
                header = i18n.getString(R.string.slot_forwarded_title),
                description = domain,
                detail = Format.date(date),
                info = i18n.getString(R.string.panel_domain_forwarded_desc),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_block)) {
                    val f = Filter(
                            id(domain, whitelist = false),
                            source = tunnel.FilterSourceDescriptor("single", domain),
                            active = true,
                            whitelist = false
                    )
                    tunnelManager.putFilter(ktx, f)
                    view.fold()
                    showSnack(R.string.panel_domain_blocked_toast)
                }
                //action2 = Slot.Action(i18n.getString(R.string.slot_action_facts), view.ACTION_NONE)
        )
        if (alternative) view.enableAlternativeBackground()
    }

}

class DomainBlockedVB(
        private val domain: String,
        private val date: Date,
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelManager: tunnel.Main = ktx.di().instance(),
        private val alternative: Boolean = false,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.BLOCK
        view.date = date
        view.content = Slot.Content(
                label = i18n.getString(R.string.panel_domain_blocked, domain),
                header = i18n.getString(R.string.slot_blocked_title),
                description = domain,
                detail = Format.date(date),
                info = i18n.getString(R.string.panel_domain_blocked_desc),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_allow)) {
                    val f = Filter(
                            id(domain, whitelist = true),
                            source = tunnel.FilterSourceDescriptor("single", domain),
                            active = true,
                            whitelist = true
                    )
                    tunnelManager.putFilter(ktx, f)
                    view.fold()
                    showSnack(R.string.panel_domain_forwarded_toast)
                }
                //action2 = Slot.Action(i18n.getString(R.string.slot_action_facts), view.ACTION_NONE)
        )
        if (alternative) view.enableAlternativeBackground()
    }

}

class FilterVB(
        private val filter: Filter,
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val filters: tunnel.Main = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        val name = filter.customName ?: i18n.localisedOrNull("filters_${filter.id}_name")
        ?: sourceToName(ctx, filter.source)
        val comment = filter.customComment ?: i18n.localisedOrNull("filters_${filter.id}_comment")

        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = name,
                description = comment,
                icon = ctx.getDrawable(R.drawable.ic_hexagon_multiple),
                switched = filter.active,
                detail = filter.source.source,
                action2 = Slot.Action(i18n.getString(R.string.slot_action_remove), {
                    filters.removeFilter(ktx, filter)
                }),
                action3 = Slot.Action(i18n.getString(R.string.slot_action_author), {
                    try {
                        Intent(Intent.ACTION_VIEW, Uri.parse(filter.credit))
                    } catch (e: Exception) {
                        null
                    }?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        ctx.startActivity(this)
                    }
                })
        )

        view.onSwitch = { on ->
            filters.putFilter(ktx, filter.copy(active = on))
        }
    }

}

class DownloadListsVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val filters: tunnel.Main = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.tunnel_config_refetch_now_title),
                description = i18n.getString(R.string.tunnel_config_refetch_now_description),
                icon = ctx.getDrawable(R.drawable.ic_download),
                action1 = Slot.Action(i18n.getString(R.string.tunnel_config_refetch_now), {
                    showSnack(R.string.tunnel_config_refetch_toast)
                    filters.invalidateFilters(ktx)
                })
        )
    }

}

class ConfigHelper {
    companion object {
        private fun ttlToId(ttl: Long) = when (ttl) {
            259200L -> R.string.tunnel_config_refetch_frequency_2
            604800L -> R.string.tunnel_config_refetch_frequency_3
            2419200L -> R.string.tunnel_config_refetch_frequency_4
            else -> R.string.tunnel_config_refetch_frequency_1
        }

        private fun idToTtl(id: Int) = when (id) {
            R.string.tunnel_config_refetch_frequency_2 -> 259200L
            R.string.tunnel_config_refetch_frequency_3 -> 604800L
            R.string.tunnel_config_refetch_frequency_4 -> 2419200L
            else -> 86400L
        }

        private fun stringToId(string: String, i18n: I18n) = when (string) {
            i18n.getString(R.string.tunnel_config_refetch_frequency_2) -> R.string.tunnel_config_refetch_frequency_2
            i18n.getString(R.string.tunnel_config_refetch_frequency_3) -> R.string.tunnel_config_refetch_frequency_3
            i18n.getString(R.string.tunnel_config_refetch_frequency_4) -> R.string.tunnel_config_refetch_frequency_4
            else -> R.string.tunnel_config_refetch_frequency_1
        }

        private fun idToString(id: Int, i18n: I18n) = i18n.getString(id)

        fun getFrequencyString(ktx: Kontext, i18n: I18n) = {
            val config = tunnel.Persistence.config.load(ktx)
            idToString(ttlToId(config.cacheTTL), i18n)
        }()

        fun setFrequency(ktx: Kontext, i18n: I18n, string: String) = {
            val config = tunnel.Persistence.config.load(ktx)
            val new = config.copy(cacheTTL = idToTtl(stringToId(string, i18n)))
            tunnel.Persistence.config.save(new)
        }()
    }
}

class ListDownloadFrequencyVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val filters: tunnel.Main = ktx.di().instance(),
        private val device: Device = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.tunnel_config_refetch_frequency_title),
                description = i18n.getString(R.string.tunnel_config_refetch_frequency_description),
                icon = ctx.getDrawable(R.drawable.ic_timer),
                values = listOf(
                        i18n.getString(R.string.tunnel_config_refetch_frequency_1),
                        i18n.getString(R.string.tunnel_config_refetch_frequency_2),
                        i18n.getString(R.string.tunnel_config_refetch_frequency_3),
                        i18n.getString(R.string.tunnel_config_refetch_frequency_4)
                ),
                selected = ConfigHelper.getFrequencyString(ktx, i18n)
        )
        view.onSelect = { selected ->
            ConfigHelper.setFrequency(ktx, i18n, selected)
            filters.reloadConfig(ktx, device.onWifi())
            view.fold()
        }
    }

}

class DownloadOnWifiVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val filters: tunnel.Main = ktx.di().instance(),
        private val device: Device = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.tunnel_config_wifi_only_title),
                description = i18n.getString(R.string.tunnel_config_wifi_only_description),
                icon = ctx.getDrawable(R.drawable.ic_wifi),
                switched = tunnel.Persistence.config.load(ktx).wifiOnly
        )
        view.onSwitch = { switched ->
            val new = tunnel.Persistence.config.load(ktx).copy(wifiOnly = switched)
            tunnel.Persistence.config.save(new)
            filters.reloadConfig(ktx, device.onWifi())
        }
    }

}

class NewFilterVB(
        private val ktx: AndroidKontext,
        private val whitelist: Boolean = false,
        private val ctx: Context = ktx.ctx,
        private val nameResId: Int = R.string.slot_new_filter,
        private val i18n: I18n = ktx.di().instance(),
        private val modal: ModalManager = modalManager
) : SlotVB() {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.NEW
        view.content = Slot.Content(i18n.getString(nameResId))
        view.onTap = {
            modal.openModal()
            ctx.startActivity(Intent(ctx, StepActivity::class.java).apply {
                putExtra(StepActivity.EXTRA_WHITELIST, whitelist)
            })
        }
    }

}

class EnterDomainVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val accepted: (List<FilterSourceDescriptor>) -> Unit = {}
) : SlotVB() {

    private var input = ""
    private var inputValid = false

    private fun validate(input: String) = when {
        validateHostname(input) -> null
        validateSeveralHostnames(input) -> null
        validateURL(input) -> null
        else -> i18n.getString(R.string.slot_enter_domain_error)
    }

    private fun validateHostname(it: String) = hostnameRegex.containsMatchIn(it.trim())
    private fun validateSeveralHostnames(it: String) = it.split(",").map { validateHostname(it) }.all { it }
    private fun validateURL(it: String) = try {
        URL(it); true
    } catch (e: Exception) {
        false
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(i18n.getString(R.string.slot_enter_domain_title),
                description = i18n.getString(R.string.slot_enter_domain_desc),
                action1 = Slot.Action(i18n.getString(R.string.slot_continue), {
                    if (inputValid) {
                        view.fold()
                        val sources = when {
                            validateSeveralHostnames(input) -> {
                                input.split(",").map {
                                    FilterSourceDescriptor("single", it.trim())
                                }
                            }
                            validateHostname(input) -> listOf(FilterSourceDescriptor("single", input.trim()))
                            else -> listOf(FilterSourceDescriptor("link", input.trim()))
                        }
                        accepted(sources)
                    }
                }),
                action2 = Slot.Action(i18n.getString(R.string.slot_enter_domain_file), view.ACTION_NONE)
        )

        view.onInput = { it ->
            input = it
            val error = validate(it)
            inputValid = error == null
            error
        }

        view.requestFocusOnEdit()
    }

}

class EnterNameVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val accepted: (String) -> Unit = {}
) : SlotVB(), Stepable {

    var inputForGeneratingName = ""
    private var input = ""
    private var inputValid = false

    private fun validate(input: String) = when {
        input.isNotBlank() -> null
        else -> i18n.getString(R.string.slot_enter_name_error)
    }

    private fun generateName(input: String) = when {
        input.isBlank() -> i18n.getString(R.string.slot_input_suggestion)
        else -> i18n.getString(R.string.slot_input_suggestion_for, input)
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(i18n.getString(R.string.slot_enter_name_title),
                description = i18n.getString(R.string.slot_enter_name_desc),
                action1 = Slot.Action(i18n.getString(R.string.slot_continue), {
                    if (inputValid) {
                        view.fold()
                        accepted(input)
                    }
                }),
                action2 = Slot.Action(i18n.getString(R.string.slot_enter_name_generate), {
                    view.input = generateName(inputForGeneratingName)
                })
        )

        view.onInput = { it ->
            input = it
            val error = validate(it)
            inputValid = error == null
            error
        }

        view.requestFocusOnEdit()
    }

}

class HomeAppVB(
        private val app: Filter,
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val filters: tunnel.Main = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.APP
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_app_label, sourceToName(ctx, app.source)),
                header = i18n.getString(R.string.slot_whitelist_title),
                description = sourceToName(ctx, app.source),
                info = i18n.getString(R.string.slot_app_desc),
                detail = app.source.source,
                icon = sourceToIcon(ctx, app.source.source),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_unwhitelist), {
                    filters.removeFilter(ktx, app)
                })
                //action2 = Slot.Action(i18n.getString(R.string.slot_action_facts), view.ACTION_NONE)
        )
    }

}

class SearchBarVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        val onSearch: (String) -> Unit,
        private val modal: ModalManager = modalManager
) : SlotVB(onTap = {
    modal.openModal()
    ctx.startActivity(Intent(ctx, SearchActivity::class.java))
    SearchActivity.setCallback { s ->
        onSearch(s)
        val label = if (s.isEmpty()) i18n.getString(R.string.search_header)
        else i18n.getString(R.string.search_entered, s)

        it.type = Slot.Type.INFO
        it.content = Slot.Content(
                label = label,
                icon = ctx.getDrawable(R.drawable.ic_search)
        )
    }
}) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        if (view.content == null) {
            view.content = Slot.Content(
                    label = i18n.getString(R.string.search_header),
                    icon = ctx.getDrawable(R.drawable.ic_search)
            )
        } else {
            view.content = Slot.Content(
                    label = view.content!!.label,
                    icon = ctx.getDrawable(R.drawable.ic_search)
            )
        }
    }
}

class EnterSearchVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val onSearch: (String) -> Unit
) : SlotVB(onTap = {}) {
    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(
                label = i18n.getString(R.string.search_title),
                icon = ctx.getDrawable(R.drawable.ic_search),
                description = i18n.getString(R.string.search_description),
                action1 = Slot.Action(i18n.getString(R.string.search_action_confirm)) {
                    onSearch((view.unfolded_edit as EditText).text.toString())
                },
                action2 = Slot.Action(ctx.getString(R.string.search_action_clear)) {
                    onSearch("")
                })

        view.requestFocusOnEdit()
    }
}

class AppVB(
        private val app: App,
        private val whitelisted: Boolean,
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val filters: tunnel.Main = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private val actionWhitelist = Slot.Action(i18n.getString(R.string.slot_allapp_whitelist)) {
        showSnack(R.string.slot_whitelist_updating)
        async {
            val filter = Filter(
                    id = filters.findFilterBySource(app.appId).await()?.id ?: id(app.appId, whitelist = true),
                    source = FilterSourceDescriptor("app", app.appId),
                    active = true,
                    whitelist = true
            )
            filters.putFilter(ktx, filter)
        }
    }

    private val actionCancel = Slot.Action(i18n.getString(R.string.slot_action_unwhitelist)) {
        showSnack(R.string.slot_whitelist_updating)
        async {
            val filter = Filter(
                    id = filters.findFilterBySource(app.appId).await()?.id ?: id(app.appId, whitelist = true),
                    source = FilterSourceDescriptor("app", app.appId),
                    active = false,
                    whitelist = true
            )
            filters.putFilter(ktx, filter)
        }
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.APP
        refresh()
    }

    private fun refresh() {
        view?.apply {
            val c = Slot.Content(
                    label = app.label,
                    header = app.label,
                    info = i18n.getString(R.string.slot_allapp_desc),
                    description = app.appId,
                    values = listOf(
                            i18n.getString(R.string.slot_allapp_whitelisted),
                            i18n.getString(R.string.slot_allapp_normal)
                    ),
                    selected = i18n.getString(if (whitelisted) R.string.slot_allapp_whitelisted else R.string.slot_allapp_normal),
                    action1 = if (whitelisted) actionCancel else actionWhitelist
                    //action2 = Slot.Action(i18n.getString(R.string.slot_action_facts), ACTION_NONE)
            )
            content = c
            setAppIcon(AppIconRequest(ctx, app, c, this))
        }
    }

    private fun setAppIcon(request: AppIconRequest) {
        request.view.tag = request.app
        val obj = handler.obtainMessage()
        obj.obj = request
        handler.sendMessageDelayed(obj, 200)
    }

    companion object {
        data class AppIconRequest(val ctx: Context, val app: App, val content: Slot.Content, val view: SlotView)

        private val handler = Handler {
            val r = it.obj as AppIconRequest
            val app = r.view.tag as App
            if (r.app == app) r.view.content = r.content.copy(icon = sourceToIcon(r.ctx, r.app.appId))
            true
        }
    }
}

class AddDnsVB(private val ktx: AndroidKontext,
               private val modal: ModalManager = modalManager): SlotVB({
    modal.openModal()
    ktx.ctx.startActivity(Intent(ktx.ctx, AddDnsActivity::class.java))}){
    override fun attach(view: SlotView) {
        view.content = Slot.Content(ktx.ctx.resources.getString(R.string.dns_custom_add_slot)
        ,icon = ktx.ctx.getDrawable(R.drawable.ic_filter_add))
    }
}

class DnsChoiceVB(
        private val item: DnsChoice,
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val dns: Dns = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()

        val id = if (item.id.startsWith("custom")) "custom" else item.id
        val name = i18n.localisedOrNull("dns_${id}_name") ?: id.capitalize()
        val description = item.comment ?: i18n.localisedOrNull("dns_${id}_comment")

        val servers = if (item.servers.isNotEmpty()) item.servers else dns.dnsServers()
        val serversString = printServers(servers)

        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = name,
                header = name,
                description = description,
                detail = serversString,
                icon = ctx.getDrawable(R.drawable.ic_server),
                switched = item.active,
                action2 = Slot.Action(i18n.getString(R.string.slot_action_author), {
                    try {
                        Intent(Intent.ACTION_VIEW, Uri.parse(item.credit))
                    } catch (e: Exception) {
                        null
                    }?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        ctx.startActivity(this)
                    }
                })
        )

        view.onSwitch = { switched ->
            if (!switched) {
                dns.choices().first().active = true
            } else {
                dns.choices().filter { it.active }.forEach { it.active = false }
            }
            item.active = switched
            dns.choices %= dns.choices()
        }
    }

}

class ActiveDnsVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val dns: Dns = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var dnsServersChanged: IWhen? = null

    override fun attach(view: SlotView) {
        dnsServersChanged = dns.dnsServers.doOnUiWhenSet().then {
            val item = dns.choices().first { it.active }
            val id = if (item.id.startsWith("custom")) "custom" else item.id
            val name = i18n.localisedOrNull("dns_${id}_name") ?: id.capitalize()
            val description = item.comment ?: i18n.localisedOrNull("dns_${id}_comment")

            view.type = Slot.Type.INFO
            view.content = Slot.Content(
                    label = i18n.getString(R.string.slot_dns_name, name),
                    header = name,
                    description = description,
                    detail = printServers(dns.dnsServers()),
                    info = i18n.getString(R.string.slot_dns_dns),
                    icon = ctx.getDrawable(R.drawable.ic_server),
//                    action1 = Slot.Action(i18n.getString(R.string.slot_action_facts), view.ACTION_NONE),
                    action1 = Slot.Action(i18n.getString(R.string.slot_action_author), {
                        try {
                            Intent(Intent.ACTION_VIEW, Uri.parse(item.credit))
                        } catch (e: Exception) {
                            null
                        }?.apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            ctx.startActivity(this)
                        }
                    })
            )
        }
    }

    override fun detach(view: SlotView) {
        dns.dnsServers.cancel(dnsServersChanged)
    }

}

class IntroVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val onRemove: () -> Unit,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getBrandedString(R.string.slot_intro_new),
                header = i18n.getString(R.string.slot_intro_new_header),
                description = i18n.getString(R.string.slot_intro_desc),
                info = i18n.getString(R.string.slot_intro_info),
                action1 = view.ACTION_REMOVE
        )
        view.onRemove = onRemove
    }

}

class StartOnBootVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val tun: Tunnel = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.main_autostart_text),
                description = i18n.getString(R.string.slot_start_on_boot_description),
                icon = ctx.getDrawable(R.drawable.ic_power),
                switched = tun.startOnBoot()
        )
        view.onSwitch = { tun.startOnBoot %= it }
    }

}

class KeepAliveVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val keepAlive: KeepAlive = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.notification_keepalive_text),
                icon = ctx.getDrawable(R.drawable.ic_heart_box),
                description = i18n.getString(R.string.notification_keepalive_description),
                switched = keepAlive.keepAlive()
        )
        view.onSwitch = { keepAlive.keepAlive %= it }
    }

}

class WatchdogVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val device: Device = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.tunnel_config_watchdog_title),
                icon = ctx.getDrawable(R.drawable.ic_earth),
                description = i18n.getString(R.string.tunnel_config_watchdog_description),
                switched = device.watchdogOn()
        )
        view.onSwitch = { device.watchdogOn %= it }
    }

}

class PowersaveVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.tunnel_config_powersave_title),
                icon = ctx.getDrawable(R.drawable.ic_power),
                description = i18n.getString(R.string.tunnel_config_powersave_description),
                switched = tunnel.Persistence.config.load(ktx).powersave
        )
        view.onSwitch = {
            val new = tunnel.Persistence.config.load(ktx).copy(powersave = it)
            tunnel.Persistence.config.save(new)
        }
    }

}

class DnsFallbackVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.tunnel_config_fallback_title),
                icon = ctx.getDrawable(R.drawable.ic_server),
                description = i18n.getString(R.string.tunnel_config_fallback_description),
                switched = tunnel.Persistence.config.load(ktx).dnsFallback
        )
        view.onSwitch = {
            val new = tunnel.Persistence.config.load(ktx).copy(dnsFallback = it)
            tunnel.Persistence.config.save(new)
        }
    }

}

class ReportVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.tunnel_config_reports_title),
                icon = ctx.getDrawable(R.drawable.ic_heart_box),
                description = i18n.getString(R.string.tunnel_config_reports_description),
                switched = tunnel.Persistence.config.load(ktx).report
        )
        view.onSwitch = {
            val new = tunnel.Persistence.config.load(ktx).copy(report = it)
            tunnel.Persistence.config.save(new)
        }
    }

}

class HomeNotificationsVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val ui: UiState = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var listener: IWhen? = null

    override fun attach(view: SlotView) {
        listener = ui.notifications.doOnUiWhenSet().then {
            val current = i18n.getString(if (ui.notifications()) R.string.slot_notifications_enabled
            else R.string.slot_notifications_disabled)
            view.type = Slot.Type.INFO
            view.content = Slot.Content(
                    label = i18n.getString(R.string.slot_notifications_title, current),
                    description = i18n.getString(R.string.slot_notifications_desc),
                    switched = ui.notifications()
            )
            view.onSwitch = { ui.notifications %= it }
        }
    }

    override fun detach(view: SlotView) {
        ui.notifications.cancel(listener)
    }
}

class NotificationsVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val ui: UiState = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.notification_on_text),
                switched = ui.notifications()
        )
        view.onSwitch = { ui.notifications %= it }
    }

}

class BackgroundAnimationVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val ui: UiState = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                icon = ktx.ctx.getDrawable(R.drawable.ic_wifi),
                label = i18n.getString(R.string.slot_background_animation),
                description = i18n.getString(R.string.slot_background_animation_description),
                switched = ui.showBgAnim()
        )
        view.onSwitch = { ui.showBgAnim %= it }
    }

}

class DnsListControlVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val dns: Dns = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_dns_control_title),
                description = i18n.getString(R.string.slot_dns_control_description),
                icon = ctx.getDrawable(R.drawable.ic_reload),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_refresh), {
                    showSnack(R.string.slot_action_refresh_toast)
                    dns.choices.refresh(force = true)
                }),
                action2 = Slot.Action(i18n.getString(R.string.slot_action_restore), {
                    dns.choices %= emptyList()
                    dns.choices.refresh()
                })
        )
    }

}

class FiltersListControlVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val filters: Filters = ktx.di().instance(),
        private val translations: g11n.Main = ktx.di().instance(),
        private val tunnel: tunnel.Main = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_filters_title),
                description = i18n.getString(R.string.slot_filters_description),
                icon = ctx.getDrawable(R.drawable.ic_reload),
                action1 = Slot.Action(i18n.getString(R.string.slot_action_refresh)) {
                    showSnack(R.string.slot_action_refresh_toast)
                    val ktx = ctx.ktx("quickActions:refresh")
                    filters.apps.refresh(force = true)
                    tunnel.invalidateFilters(ktx)
                    translations.invalidateCache(ktx)
                    translations.sync(ktx)
                },
                action2 = Slot.Action(i18n.getString(R.string.slot_action_restore)) {
                    val ktx = ctx.ktx("quickActions:restore")
                    filters.apps.refresh(force = true)
                    tunnel.deleteAllFilters(ktx)
                    translations.invalidateCache(ktx)
                    translations.sync(ktx)
                }
        )
    }

}

class StorageLocationVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val activity: ComponentProvider<android.app.Activity> = ktx.di().instance(),
        private val filters: tunnel.Main = ktx.di().instance(),
        private val device: Device = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private val actionExternal = Slot.Action(i18n.getString(R.string.slot_action_external), {
        ktx.v("set persistence path", getExternalPath())
        Persistence.global.savePath(getExternalPath())

        if (!checkStoragePermissions(ktx)) {
            activity.get()?.apply {
                askStoragePermission(ktx, this)
            }
        }
        view?.apply { attach(this) }
    })

    private val actionInternal = Slot.Action(i18n.getString(R.string.slot_action_internal), {
        ktx.v("resetting persistence path")
        Persistence.global.savePath(Persistence.DEFAULT_PATH)
        view?.apply { attach(this) }
    })

    private val actionImport = Slot.Action(i18n.getString(R.string.slot_action_import), {
        filters.reloadConfig(ktx, device.onWifi())
    })

    private fun isExternal() = Persistence.global.loadPath() != Persistence.DEFAULT_PATH

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_export_title),
                description = i18n.getString(R.string.slot_export_description),
                icon = ctx.getDrawable(R.drawable.ic_settings_outline),
                values = listOf(
                        i18n.getString(R.string.slot_action_internal),
                        i18n.getString(R.string.slot_action_external)
                ),
                selected = i18n.getString(if (isExternal()) R.string.slot_action_external
                else R.string.slot_action_internal),
                action1 = if (isExternal()) actionInternal else actionExternal,
                action2 = actionImport
        )
    }

}

fun openInBrowser(ctx: Context, url: URL) {
    val intent = Intent(Intent.ACTION_VIEW)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    intent.setData(Uri.parse(url.toString()))
    ctx.startActivity(intent)
}

class UpdateVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val repo: Repo = ktx.di().instance(),
        private val ver: Version = ktx.di().instance(),
        private val pages: Pages = ktx.di().instance(),
        private val updater: UpdateCoordinator = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var listener: IWhen? = null
    private var clickCounter = 0
    private var next: Int = 0

    private val changelogAction = Slot.Action(i18n.getString(R.string.main_changelog)) {
        openInBrowser(ctx, pages.changelog())
    }

    override fun attach(view: SlotView) {
        listener = repo.lastRefreshMillis.doOnUiWhenSet().then {
            val current = repo.content()
            view.type = Slot.Type.INFO

            if (isUpdate(ctx, current.newestVersionCode)) {
                view.content = Slot.Content(
                        label = i18n.getString(R.string.update_dash_available),
                        description = i18n.getString(R.string.update_notification_text, current.newestVersionName),
                        action1 = Slot.Action(i18n.getString(R.string.update_button)) {
                            if (clickCounter++ % 2 == 0) {
                                showSnack(R.string.update_starting)
                                updater.start(repo.content().downloadLinks)
                            } else {
                                val intent = Intent(Intent.ACTION_VIEW)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                intent.setData(Uri.parse(repo.content().downloadLinks[next].toString()))
                                ctx.startActivity(intent)

                                next = next++ % repo.content().downloadLinks.size
                            }
                        },
                        icon = ctx.getDrawable(R.drawable.ic_new_releases),
                        action2 = changelogAction
                )
                view.date = Date()
            } else {
                view.content = Slot.Content(
                        label = i18n.getString(R.string.slot_update_no_updates),
                        description = i18n.getString(R.string.update_info),
                        action1 = Slot.Action(i18n.getString(R.string.slot_update_action_refresh), {
                            repo.content.refresh(force = true)
                        }),
                        icon = ctx.getDrawable(R.drawable.ic_reload),
                        action2 = changelogAction
                )
                view.date = Date(repo.lastRefreshMillis())
            }
        }
    }

    override fun detach(view: SlotView) {
        repo.lastRefreshMillis.cancel(listener)
    }
}

class AboutVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val ver: Version = ktx.di().instance(),
        private val pages: Pages = ktx.di().instance(),
        private val activity: ComponentProvider<Activity> = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private val creditsAction = Slot.Action(i18n.getString(R.string.main_credits)) {
        openInBrowser(ctx, pages.credits())
    }

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO

        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_about),
                description = "${ver.appName} ${ver.name}",
                detail = blokadaUserAgent(ctx),
                action2 = creditsAction,
                action3 = Slot.Action(i18n.getString(R.string.update_button_appinfo)) {
                    try {
                        ctx.startActivity(newAppDetailsIntent(ctx.packageName))
                    } catch (e: Exception) {
                    }
                },
                action1 = Slot.Action(i18n.getString(R.string.slot_about_share_log)) {
//                    if (askForExternalStoragePermissionsIfNeeded(activity)) {
                        val uri = File(ctx.filesDir, "/blokada.log")
                        val openFileIntent = Intent(Intent.ACTION_SEND)
                        openFileIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        openFileIntent.type = "plain/*"
                        openFileIntent.putExtra(Intent.EXTRA_STREAM, FileProvider.getUriForFile(ktx.ctx, "${ktx.ctx.packageName}.files",
                                uri))
                        ktx.ctx.startActivity(openFileIntent)
//                    }
                }
        )
    }

    private fun newAppDetailsIntent(packageName: String): Intent {
        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        intent.data = Uri.parse("package:" + packageName)
        return intent
    }

    private fun askForExternalStoragePermissionsIfNeeded(activity: ComponentProvider<Activity>): Boolean {
        return if (!checkStoragePermissions(ktx)) {
            activity.get()?.apply {
                askStoragePermission(ktx, this)
            }
            false
        } else true
    }
}

class TelegramVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val pages: Pages = ktx.di().instance(),
        private val onRemove: () -> Unit,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_telegram_title),
                description = i18n.getString(R.string.slot_telegram_desc),
                icon = ctx.getDrawable(R.drawable.ic_comment_multiple_outline),
                action1 = Slot.Action(i18n.getString(R.string.slot_telegram_action), {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        intent.data = Uri.parse(pages.chat().toString())
                        ctx.startActivity(intent)
                    } catch (e: Exception) {
                    }
                }),
                action2 = view.ACTION_REMOVE
        )
        view.onRemove = onRemove
    }

}

class AdblockingVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private val update = { cfg: BlockaConfig ->
        view?.apply {
            content = Slot.Content(
                    label = i18n.getString(R.string.slot_adblocking_label),
                    icon = ktx.ctx.getDrawable(R.drawable.ic_block),
                    description = i18n.getString(R.string.slot_adblocking_text),
                    switched = cfg.adblocking
            )
            onSwitch = {
                ktx.emit(BLOCKA_CONFIG, cfg.copy(adblocking = !cfg.adblocking))
            }
        }
        Unit
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        ktx.on(BLOCKA_CONFIG, update)
    }

    override fun detach(view: SlotView) {
        ktx.cancel(BLOCKA_CONFIG, update)
    }
}

class BlockaVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit,
        private val modal: ModalManager = modalManager
) : SlotVB(onTap) {

    private val update = { cfg: BlockaConfig? ->
        view?.apply {
            val isActive = cfg?.activeUntil?.after(Date()) ?: false
            val accountId = i18n.getString(R.string.slot_account_text_account, cfg?.accountId ?: "")
            val accountLabel = if (isActive)
                i18n.getString(R.string.slot_account_text_active, cfg!!.activeUntil.pretty(ktx))
            else i18n.getString(R.string.slot_account_text_inactive)

            if (cfg != null) {
                content = Slot.Content(
                        label = i18n.getString(R.string.slot_blocka_label),
                        icon = ktx.ctx.getDrawable(R.drawable.ic_account_circle_black_24dp),
                        description = "%s<br/><br/>%s".format(accountId, accountLabel),
                        color = if (isActive) ktx.ctx.resources.getColor(R.color.colorProtectionHigh) else null,
                        action1 = Slot.Action(
                                if (isActive) i18n.getString(R.string.slot_account_action_manage)
                                else i18n.getString(R.string.slot_account_action_manage_inactive)) {
                            modal.openModal()
                            ktx.ctx.startActivity(Intent(ktx.ctx, SubscriptionActivity::class.java))
                        },
                        action2 = Slot.Action(i18n.getString(R.string.slot_account_action_change_id)) {
                            modal.openModal()
                            ktx.ctx.startActivity(Intent(ktx.ctx, RestoreAccountActivity::class.java))
                        },
                        action3 = Slot.Action(i18n.getString(R.string.slot_account_action_copy)) {
                            val clipboardManager = ktx.ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            val clipData = ClipData.newPlainText("account-id", cfg.accountId)
                            clipboardManager.primaryClip = clipData
                            showSnack(R.string.slot_account_action_copied)
                        }
                )
            } else {
                content = Slot.Content(
                        label = i18n.getString(R.string.slot_blocka_label),
                        icon = ktx.ctx.getDrawable(R.drawable.ic_account_circle_black_24dp),
                        description = "%s<br/><br/>%s".format(accountId, accountLabel)
                )
            }

        }
        view?.type = Slot.Type.ACCOUNT
        Unit
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view?.type = Slot.Type.ACCOUNT
        update(null)
        ktx.on(BLOCKA_CONFIG, update)
    }

    override fun detach(view: SlotView) {
        ktx.cancel(BLOCKA_CONFIG, update)
    }
}

class GatewayVB(
        private val ktx: AndroidKontext,
        private val gateway: RestModel.GatewayInfo,
        private val i18n: I18n = ktx.di().instance(),
        private val modal: ModalManager = modalManager,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private fun update(cfg: BlockaConfig) {
        view?.apply {
            content = Slot.Content(
                    label = i18n.getString(
                            (if (gateway.overloaded()) R.string.slot_gateway_label_overloaded
                            else R.string.slot_gateway_label),
                            gateway.niceName()),
                    icon = ktx.ctx.getDrawable(
                            if (gateway.overloaded()) R.drawable.ic_shield_outline
                            else R.drawable.ic_verified
                    ),
                    description = if (gateway.publicKey == cfg.gatewayId) {
                        i18n.getString(R.string.slot_gateway_description_current,
                                getLoad(gateway.resourceUsagePercent), gateway.ipv4, gateway.region,
                                cfg.activeUntil)
                    } else {
                        i18n.getString(R.string.slot_gateway_description,
                                getLoad(gateway.resourceUsagePercent), gateway.ipv4, gateway.region)
                    },
                    switched = gateway.publicKey == cfg.gatewayId
            )

            onSwitch = {
                when {
                    gateway.publicKey == cfg.gatewayId -> {
                        // Turn off VPN feature
                        clearConnectedGateway(ktx, cfg, showError = false)
                    }
                    cfg.activeUntil.before(Date()) -> {
                        modal.openModal()
                        ktx.ctx.startActivity(Intent(ktx.ctx, SubscriptionActivity::class.java))
                    }
                    gateway.overloaded() -> {
                        showSnack(R.string.slot_gateway_overloaded)
                        // Resend event to re-select same gateway
                        ktx.emit(BLOCKA_CONFIG, cfg)
                    }
                    else -> {
                        checkGateways(ktx, cfg.copy(
                                gatewayId = gateway.publicKey,
                                gatewayIp = gateway.ipv4,
                                gatewayPort = gateway.port,
                                gatewayNiceName = gateway.niceName()
                        ))
                    }
                }
            }
        }
    }

    private fun getLoad(usage: Int): String {
        return i18n.getString(when (usage) {
            in 0..50 -> R.string.slot_gateway_load_low
            else -> R.string.slot_gateway_load_high
        })
    }

    private val onConfig = { cfg: BlockaConfig ->
        update(cfg)
        Unit
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        ktx.on(BLOCKA_CONFIG, onConfig)
    }

    override fun detach(view: SlotView) {
        ktx.cancel(BLOCKA_CONFIG, onConfig)
    }
}

private val prettyFormat = SimpleDateFormat("MMMM dd, HH:mm")
fun Date.pretty(ktx: Kontext): String {
    return prettyFormat.format(this)
}

class RecommendedDnsVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val dns: Dns = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private fun update() {
        view?.enableAlternativeBackground()
        view?.type = Slot.Type.INFO
        view?.content = Slot.Content(
                label = i18n.getString(R.string.slot_recommended_dns_label),
                description = i18n.getString(R.string.slot_recommended_dns_description),
                icon = ktx.ctx.getDrawable(R.drawable.ic_server),
                switched = hasGoodDnsServers(dns)
        )
        view?.onSwitch = { useRecommended ->
            // Clear currently active dns
            val active = dns.choices().firstOrNull { it.active }
            active?.active = false

            if (useRecommended) {
                var recommended = dns.choices().firstOrNull { it.id.contains("cloudflare") }
                if (recommended == null) {
                    recommended = dns.choices().firstOrNull { it.id != "default" }
                }
                if (recommended != null) {
                    recommended.active = true
                    dns.choices %= dns.choices()
                }
            } else {
                val default = dns.choices().firstOrNull { it.id == "default" }
                default?.active = true
                dns.choices %= dns.choices()
            }
        }
    }

    override fun attach(view: SlotView) {
        onDnsChoiceChanged = dns.choices.doOnUiWhenSet().then { update() }
    }

    override fun detach(view: SlotView) {
        dns.choices.cancel(onDnsChoiceChanged)
    }

    private var onDnsChoiceChanged: IWhen? = null

}

private fun hasGoodDnsServers(dns: Dns): Boolean {
    val active = dns.choices().firstOrNull { it.active }
    return active != null && active.id != "default"
}

class DonateVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val pages: Pages = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance(),
        private val onRemove: () -> Unit,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_donate_label),
                description = i18n.getString(R.string.slot_donate_desc),
                icon = ctx.getDrawable(R.drawable.ic_heart_box),
                action1 = Slot.Action(i18n.getString(R.string.slot_donate_action), {
                    openInBrowser(ctx, pages.donate())
                }),
                action2 = view.ACTION_REMOVE
        )
        view.onRemove = onRemove
    }
}

class BlogVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val pages: Pages = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance(),
        private val onRemove: () -> Unit,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_blog_label),
                description = i18n.getString(R.string.slot_blog_desc),
                icon = ctx.getDrawable(R.drawable.ic_earth),
                action1 = Slot.Action(i18n.getString(R.string.slot_blog_action), {
                    openInBrowser(ctx, pages.news())
                }),
                action2 = view.ACTION_REMOVE
        )
        view.onRemove = onRemove
    }
}

class HelpVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val pages: Pages = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_help_label),
                description = i18n.getString(R.string.slot_help_desc),
                icon = ctx.getDrawable(R.drawable.ic_help_outline),
                action1 = Slot.Action(i18n.getString(R.string.slot_help_action), {
                    openInBrowser(ctx, pages.help())
                })
        )
    }
}

class CtaVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val pages: Pages = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance(),
        private val onRemove: () -> Unit,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_cta_label),
                description = i18n.getString(R.string.slot_cta_desc),
                icon = ctx.getDrawable(R.drawable.ic_comment_multiple_outline),
                action1 = Slot.Action(i18n.getString(R.string.slot_cta_action), {
                    openInBrowser(ctx, pages.cta())
                }),
                action2 = view.ACTION_REMOVE
        )
        view.onRemove = onRemove
    }
}

class ObsoleteVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val pages: Pages = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_obsolete_label),
                description = i18n.getString(R.string.slot_obsolete_desc),
                icon = ctx.getDrawable(R.drawable.ic_new_releases),
                action1 = Slot.Action(i18n.getString(R.string.slot_obsolete_action), {
                    openInBrowser(ctx, pages.download())
                })
        )
    }
}

class UpdatedVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val pages: Pages = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance(),
        private val onRemove: () -> Unit,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_updated_label),
                description = i18n.getString(R.string.slot_updated_desc),
                icon = ctx.getDrawable(R.drawable.ic_reload),
                action1 = Slot.Action(i18n.getString(R.string.slot_updated_action), {
                    openInBrowser(ctx, pages.updated())
                }),
                action2 = Slot.Action(i18n.getString(R.string.slot_donate_action), {
                    openInBrowser(ctx, pages.donate())
                }),
                action3 = view.ACTION_REMOVE
        )
        view.onRemove = onRemove
    }
}

class CleanupVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val pages: Pages = ktx.di().instance(),
        private val welcome: Welcome = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.slot_cleanup_label),
                description = i18n.getString(R.string.slot_cleanup_desc),
                icon = ctx.getDrawable(R.drawable.ic_delete),
                action1 = Slot.Action(i18n.getString(R.string.slot_cleanup_action)) {
                    showSnack(R.string.welcome_cleanup_done)
                    val builds = getInstalledBuilds()
                    for (b in builds.subList(1, builds.size).reversed()) {
                        uninstallPackage(b)
                    }
                }
        )
    }

    private fun getInstalledBuilds(): List<String> {
        return welcome.conflictingBuilds().map {
            if (isPackageInstalled(it)) it else null
        }.filterNotNull()
    }

    private fun isPackageInstalled(appId: String): Boolean {
        val intent = ctx.packageManager.getLaunchIntentForPackage(appId) as Intent? ?: return false
        val activities = ctx.packageManager.queryIntentActivities(intent, 0)
        return activities.size > 0
    }

    private fun uninstallPackage(appId: String) {
        try {
            val intent = Intent(Intent.ACTION_DELETE)
            intent.data = Uri.parse("package:" + appId)
            ctx.startActivity(intent)
        } catch (e: Exception) {
            ktx.e(e)
        }
    }
}

