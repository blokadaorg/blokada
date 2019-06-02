package core

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.widget.Toast
import com.github.salomonbrys.kodein.instance
import filter.hostnameRegex
import filter.id
import filter.sourceToIcon
import filter.sourceToName
import gs.environment.ComponentProvider
import gs.property.*
import kotlinx.coroutines.experimental.async
import org.blokada.R
import tunnel.*
import tunnel.Filter
import update.UpdateCoordinator
import update.isUpdate
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

class AppStatusVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: EnabledStateActor = ktx.di().instance(),
        private val tunnelEvents2: Tunnel = ktx.di().instance(),
        private val s: Tunnel = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var statusResId: Int? = null
    private var actionResId: Int? = null
    private var dropped: Int = 0

    private val update = { statusResId: Int, actionResId: Int, dropped: Int ->
        view?.apply {
            val statusString = i18n.getBrandedString(statusResId)
            val droppedString = i18n.getString(R.string.tunnel_dropped_count2,
                    Format.counter(tunnelEvents2.tunnelDropCount()))
            content = Slot.Content(
                    icon = ktx.ctx.getDrawable(R.drawable.ic_block),
                    label = if (statusResId == R.string.main_active) droppedString else statusString,
                    header = droppedString,
                    description = if (statusResId == R.string.main_active)
                        i18n.getString(R.string.slot_status_description_active) else statusString,
                    info = i18n.getString(R.string.slot_status_info),
                    detail = Format.date(Date()),
                    action1 = Slot.Action(i18n.getString(R.string.slot_action_share), {
                        val shareIntent: Intent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, ktx.ctx.getString(R.string.slot_dropped_share,
                                    Format.counter(tunnelEvents2.tunnelDropCount()),
                                    ktx.ctx.getString(R.string.branding_app_name_short)))
                            type = "image/jpeg"
                        }
                        ktx.ctx.startActivity(Intent.createChooser(shareIntent,
                                ktx.ctx.getText(R.string.slot_dropped_share_title)))
                    }),
                    action2 = Slot.Action(i18n.getString(actionResId), {
                        if (actionResId == R.string.slot_action_activate) s.enabled %= true
                        else s.enabled %= false
                    }),
                    action3 = Slot.Action(i18n.getString(R.string.slot_dropped_action_clear), {
                        tunnelEvents2.tunnelDropCount %= 0
                    })
            )
        }
        Unit
    }

    private val tunnelListener = object : IEnabledStateActorListener {
        override fun startActivating() = update(R.string.main_status_activating, R.string.slot_action_deactivate, dropped)
        override fun finishActivating() = update(R.string.main_active, R.string.slot_action_deactivate, dropped)
        override fun startDeactivating() = update(R.string.main_deactivating_new, R.string.slot_action_deactivate, dropped)
        override fun finishDeactivating() = update(R.string.main_paused, R.string.slot_action_activate, dropped)
    }

//    private val configListener = { cfg: BlockaConfig ->
//        config = cfg
//        statusResId?.let { status ->
//            actionResId?.let { action ->
//                update(status, action, cfg)
//            }
//        }
//        Unit
//    }

    private var droppedCountListener: IWhen? = null

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        tunnelEvents.listeners.add(tunnelListener)
        tunnelEvents.update(s)
        droppedCountListener = tunnelEvents2.tunnelDropCount.doOnUiWhenSet().then {
            dropped = tunnelEvents2.tunnelDropCount()
            statusResId?.let { status ->
                actionResId?.let { action ->
                    update(status, action, dropped)
                }
            }
        }
    }

    override fun detach(view: SlotView) {
        tunnelEvents.listeners.remove(tunnelListener)
        tunnelEvents2.tunnelDropCount.cancel(droppedCountListener)
    }

}

class VpnStatusVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: EnabledStateActor = ktx.di().instance(),
        private val tunnelEvents2: Tunnel = ktx.di().instance(),
        private val s: Tunnel = ktx.di().instance(),
        private val modal: ModalManager = modalManager,
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private val update = { config: BlockaConfig ->
        view?.apply {
            content = Slot.Content(
                    icon = ktx.ctx.getDrawable(R.drawable.ic_shield_key_outline),
                    label = if (config.blockaVpn)
                        i18n.getString(R.string.slot_status_vpn_turned_on, config.gatewayNiceName)
                        else i18n.getString(R.string.slot_status_vpn_turned_off),
                    description = if (config.blockaVpn) {
                        i18n.getString(R.string.slot_status_vpn_desc_on, config.gatewayIp)
                    } else i18n.getString(R.string.slot_status_vpn_desc_off),
                    info = i18n.getString(R.string.slot_status_vpn_info),
                    detail = Format.date(Date()),
                    action1 = Slot.Action(i18n.getString(
                            if (config.blockaVpn) R.string.slot_status_vpn_turn_off
                            else R.string.slot_status_vpn_turn_on
                    ), {
                        if (config.activeUntil.before(Date())) {
                            modal.openModal()
                            ktx.ctx.startActivity(Intent(ktx.ctx, SubscriptionActivity::class.java))
                        } else {
                            Toast.makeText(ktx.ctx, i18n.getString(
                                    if (config.blockaVpn) R.string.slot_status_vpn_turned_off
                                    else R.string.slot_status_vpn_connecting
                            ), Toast.LENGTH_LONG).show()

                            ktx.emit(BLOCKA_CONFIG, config.copy(blockaVpn = !config.blockaVpn))
                        }
                    }),
                    action2 = Slot.Action(i18n.getString(R.string.slot_status_vpn_lease), {
                        async {
                            checkLease(ktx, config)
                        }
                    })
            )
            date = Date()
        }
        Unit
    }

    private val configListener = { cfg: BlockaConfig ->
        update(cfg)
        Unit
    }

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        ktx.on(BLOCKA_CONFIG, configListener)
    }

    override fun detach(view: SlotView) {
        ktx.cancel(BLOCKA_CONFIG, configListener)
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
            action1 = Slot.Action(i18n.getString(R.string.slot_action_block), {
                val f = Filter(
                        id(domain, whitelist = false),
                        source = tunnel.FilterSourceDescriptor("single", domain),
                        active = true,
                        whitelist = false
                )
                tunnelManager.putFilter(ktx, f)
                view.fold()
                Toast.makeText(ktx.ctx, i18n.getString(R.string.panel_domain_blocked_toast), Toast.LENGTH_SHORT).show()
            }),
            action2 = Slot.Action(i18n.getString(R.string.slot_action_facts), view.ACTION_NONE)
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
            action1 = Slot.Action(i18n.getString(R.string.slot_action_allow), {
                val f = Filter(
                        id(domain, whitelist = true),
                        source = tunnel.FilterSourceDescriptor("single", domain),
                        active = true,
                        whitelist = true
                )
                tunnelManager.putFilter(ktx, f)
                view.fold()
                Toast.makeText(ktx.ctx, i18n.getString(R.string.panel_domain_forwarded_toast), Toast.LENGTH_SHORT).show()
            }),
            action2 = Slot.Action(i18n.getString(R.string.slot_action_facts), view.ACTION_NONE)
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
        val name = filter.customName ?: i18n.localisedOrNull("filters_${filter.id}_name") ?: sourceToName(ctx, filter.source)
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
                    } catch (e: Exception) { null }?.apply {
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
                    filters.invalidateFilters(ktx)
                })
        )
    }

}

class ConfigHelper {
    companion object {
        private fun ttlToId(ttl: Long) = when(ttl) {
            259200L -> R.string.tunnel_config_refetch_frequency_2
            604800L -> R.string.tunnel_config_refetch_frequency_3
            2419200L -> R.string.tunnel_config_refetch_frequency_4
            else -> R.string.tunnel_config_refetch_frequency_1
        }

        private fun idToTtl(id: Int) = when(id) {
            R.id.frequency_2 -> 259200L
            R.id.frequency_3 -> 604800L
            R.id.frequency_4 -> 2419200L
            else -> 86400L
        }

        private fun stringToId(string: String, i18n: I18n) = when(string) {
            i18n.getString(R.id.frequency_2) -> R.id.frequency_2
            i18n.getString(R.id.frequency_3) -> R.id.frequency_3
            i18n.getString(R.id.frequency_4) -> R.id.frequency_4
            else -> R.id.frequency_1
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
        private val i18n: I18n = ktx.di().instance(),
        private val modal: ModalManager = modalManager
) : SlotVB() {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.NEW
        view.content = Slot.Content(i18n.getString(R.string.slot_new_filter))
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
    private fun validateURL(it: String) = try { URL(it); true } catch (e: Exception) { false }

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
                }),
                action2 = Slot.Action(i18n.getString(R.string.slot_action_facts), view.ACTION_NONE)
        )
    }

}

class AppVB(
        private val app: App,
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val filters: tunnel.Main = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private val actionWhitelist = Slot.Action(i18n.getString(R.string.slot_allapp_whitelist), {
        val filter = Filter(
                id = id(app.appId, whitelist = true),
                source = FilterSourceDescriptor("app", app.appId),
                active = true,
                whitelist = true
        )
        filters.putFilter(ktx, filter)
    })

    private var filter: Filter? = null

    private val actionCancel = Slot.Action(i18n.getString(R.string.slot_action_unwhitelist), {
        filter?.apply { filters.removeFilter(ktx, this) }
    })

    private val onFilters = { filters: Collection<Filter> ->
        filter = filters.firstOrNull { it.source.id == "app" && it.source.source == app.appId
            && it.active
        }
        refresh()
        Unit
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.APP
        ktx.on(Events.FILTERS_CHANGED, onFilters)
        refresh()
    }

    private fun refresh() {
        view?.apply {
             val c = Slot.Content(
                    label = app.label,
                    header = app.label,
                    info = i18n.getString(R.string.slot_allapp_desc),
                    detail = app.appId,
                    values = listOf(
                            i18n.getString(R.string.slot_allapp_whitelisted),
                            i18n.getString(R.string.slot_allapp_normal)
                    ),
                    selected = i18n.getString(if (filter != null) R.string.slot_allapp_whitelisted else R.string.slot_allapp_normal),
                    action1 = if (filter != null) actionCancel else actionWhitelist,
                    action2 = Slot.Action(i18n.getString(R.string.slot_action_facts), ACTION_NONE)
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

    override fun detach(view: SlotView) {
        ktx.cancel(Events.FILTERS_CHANGED, onFilters)
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
                    } catch (e: Exception) { null }?.apply {
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
                    action1 = Slot.Action(i18n.getString(R.string.slot_action_facts), view.ACTION_NONE),
                    action2 = Slot.Action(i18n.getString(R.string.slot_action_author), {
                        try {
                            Intent(Intent.ACTION_VIEW, Uri.parse(item.credit))
                        } catch (e: Exception) { null }?.apply {
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
                action1 = Slot.Action(i18n.getString(R.string.slot_action_refresh), {
                    val ktx = ctx.ktx("quickActions:refresh")
                    filters.apps.refresh(force = true)
                    tunnel.invalidateFilters(ktx)
                    translations.invalidateCache(ktx)
                    translations.sync(ktx)
                }),
                action2 = Slot.Action(i18n.getString(R.string.slot_action_restore), {
                    val ktx = ctx.ktx("quickActions:restore")
                    filters.apps.refresh(force = true)
                    tunnel.deleteAllFilters(ktx)
                    translations.invalidateCache(ktx)
                    translations.sync(ktx)
                })
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

class UpdateVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val repo: Repo = ktx.di().instance(),
        private val ver: Version = ktx.di().instance(),
        private val updater: UpdateCoordinator = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private var listener: IWhen? = null
    private var clickCounter = 0
    private var next: Int = 0

    override fun attach(view: SlotView) {
        listener = repo.lastRefreshMillis.doOnUiWhenSet().then {
            val current = repo.content()
            view.type = Slot.Type.INFO

            if (isUpdate(ctx, current.newestVersionCode)) {
                view.content = Slot.Content(
                        label = i18n.getString(R.string.update_dash_available),
                        description = i18n.getString(R.string.update_notification_text, current.newestVersionName),
                        action1 = Slot.Action(i18n.getString(R.string.update_button), {
                            if (clickCounter++ % 2 == 0) {
                                Toast.makeText(ctx, R.string.update_starting, Toast.LENGTH_SHORT).show()
                                updater.start(repo.content().downloadLinks)
                            } else {
                                val intent = Intent(Intent.ACTION_VIEW)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                intent.setData(Uri.parse(repo.content().downloadLinks[next].toString()))
                                ctx.startActivity(intent)

                                next = next++ % repo.content().downloadLinks.size
                            }
                        })
                )
                view.date = Date()
            } else {
                view.content = Slot.Content(
                        label = i18n.getString(R.string.update_header_noupdate),
                        header = "${ver.appName} ${ver.name}",
                        description = i18n.getString(R.string.update_info),
                        action1 = Slot.Action(i18n.getString(R.string.slot_update_action_refresh), {
                            repo.content.refresh(force = true)
                        }),
                        action2 = Slot.Action(i18n.getString(R.string.update_button_appinfo), {
                            try { ctx.startActivity(newAppDetailsIntent(ctx.packageName)) } catch (e: Exception) {}
                        })
                )
                view.date = Date(repo.lastRefreshMillis())
            }
        }
    }

    override fun detach(view: SlotView) {
        repo.lastRefreshMillis.cancel(listener)
    }

    private fun newAppDetailsIntent(packageName: String): Intent {
        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        intent.data = Uri.parse("package:" + packageName)
        return intent
    }
}

class TelegramVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val pages: Pages = ktx.di().instance(),
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
                    } catch (e: Exception) {}
                })
        )
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

    private val update = { cfg: BlockaConfig ->
        view?.apply {
            content = Slot.Content(
                    label = i18n.getString(R.string.slot_blocka_label),
                    icon = ktx.ctx.getDrawable(R.drawable.ic_shield_key_outline),
                    description = i18n.getString(R.string.slot_blocka_text),
                    switched = cfg.blockaVpn
            )

            onSwitch = {
                if (cfg.activeUntil.before(Date())) {
                    modal.openModal()
                    ktx.ctx.startActivity(Intent(ktx.ctx, SubscriptionActivity::class.java))
                } else ktx.emit(BLOCKA_CONFIG, cfg.copy(blockaVpn = !cfg.blockaVpn))
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

class AccountVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit,
        private val modal: ModalManager = modalManager
) : SlotVB(onTap) {

    private var tunnelCfg: TunnelConfig? = null
    private var blocka: BlockaConfig? = null

    private val update = {
        tunnelCfg?.run {
            blocka?.run {
                val isActive = activeUntil.after(Date())
                view?.apply {
                    content = Slot.Content(
                            label = if (isActive) i18n.getString(R.string.slot_account_label_active, activeUntil.pretty(ktx))
                                else i18n.getString(R.string.slot_account_label),
                            header = i18n.getString(R.string.slot_account_label),
                            icon = ktx.ctx.getDrawable(R.drawable.ic_account_circle_black_24dp),
                            description =  i18n.getString(R.string.slot_account_text,
                                    i18n.getString(R.string.slot_account_text_account, accountId),
                                    if (isActive) i18n.getString(R.string.slot_account_text_active, activeUntil.pretty(ktx))
                                    else i18n.getString(R.string.slot_account_text_inactive)
                            ),
                            switched = isActive,
                            action1 = Slot.Action(
                                    if (isActive) i18n.getString(R.string.slot_account_action_manage)
                                        else i18n.getString(R.string.slot_account_action_manage_inactive), {
                                modal.openModal()
                                ktx.ctx.startActivity(Intent(ktx.ctx, SubscriptionActivity::class.java))
                            }),
                            action2 = Slot.Action(i18n.getString(R.string.slot_account_action_change_id), {

                            })
                    )
                    onSwitch = {  }
                }
            }
        }
        Unit
    }

    private val onTunnel = { cfg: TunnelConfig ->
        tunnelCfg = cfg
        update()
    }

    private val onBlocka = { cfg: BlockaConfig ->
        blocka = cfg
        update()
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        ktx.on(TUNNEL_CONFIG, onTunnel)
        ktx.on(BLOCKA_CONFIG, onBlocka)
    }

    override fun detach(view: SlotView) {
        ktx.cancel(TUNNEL_CONFIG, onTunnel)
        ktx.cancel(BLOCKA_CONFIG, onBlocka)
    }
}

class GatewayVB(
        private val ktx: AndroidKontext,
        private val gateway: RestModel.GatewayInfo,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    private fun update(cfg: BlockaConfig? = null) {
        view?.apply {
            content = Slot.Content(
                    label = i18n.getString(R.string.slot_gateway_label, gateway.niceName()),
                    icon = ktx.ctx.getDrawable(R.drawable.ic_server),
                    description = if (gateway.publicKey == cfg?.gatewayId) {
                        i18n.getString(R.string.slot_gateway_description_current,
                                getLoad(gateway.resourceUsagePercent), gateway.ipv4, gateway.region,
                                cfg.activeUntil)
                    } else {
                        i18n.getString(R.string.slot_gateway_description,
                                getLoad(gateway.resourceUsagePercent), gateway.ipv4, gateway.region)
                    },
                    switched = gateway.publicKey == cfg?.gatewayId
            )

            onSwitch = {
                if (gateway.publicKey == cfg?.gatewayId) {
                    // cant 'unselect' for now
                } else {
                    cfg?.run {
                        redoLease(ktx, this, gateway)
                    }
                }
            }
        }
    }

    private fun getLoad(usage: Int): String {
        return i18n.getString(when(usage) {
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
