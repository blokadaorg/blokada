package core.bits

import android.content.Context
import android.util.Base64
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.menu.MENU_CLICK_BY_NAME
import gs.property.I18n
import gs.property.IWhen
import org.blokada.R
import tunnel.showSnack
import java.nio.charset.Charset

class ActiveDnsVB(
        private val ktx: AndroidKontext,
        private val simple: Boolean = false,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val tunnelEvents: Tunnel = ktx.di().instance(),
        private val tunnelStatus: EnabledStateActor = ktx.di().instance(),
        private val dns: Dns = ktx.di().instance()
) : ByteVB() {

    private var dnsServersChanged: IWhen? = null
    private var dnsEnabledChanged: IWhen? = null
    private var active = false
    private var activating = false

    override fun attach(view: ByteView) {
        dnsServersChanged = dns.dnsServers.doOnUiWhenSet().then(update)
        dnsEnabledChanged = dns.enabled.doOnUiWhenSet().then(update)
        tunnelStatus.listeners.add(tunnelListener)
        tunnelStatus.update(tunnelEvents)
        update()
    }

    override fun detach(view: ByteView) {
        dns.dnsServers.cancel(dnsServersChanged)
        dns.enabled.cancel(dnsEnabledChanged)
        tunnelStatus.listeners.remove(tunnelListener)
    }

    private val update = {
        view?.run {
            when {
                !tunnelEvents.enabled() -> {
                    setTexts(null)
                    switch(null)
                    arrow(null)
                    onTap {
                        tunnelEvents.enabled %= true
                        onSwitch { enabled ->
                            when {
                                !dns.hasCustomDnsSelected() -> {
                                    showSnack(R.string.menu_dns_select.res())
                                    ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                                    switch(false)
                                }
                                else -> {
                                    entrypoint.onSwitchDnsEnabled(enabled)
                                }
                            }
                        }
                    }
                }
                activating || !active -> {
                    icon(R.drawable.ic_show.res())
                    label(R.string.home_activating.res())
                    state(R.string.home_please_wait.res())
                    switch(null)
                    arrow(null)
                    onTap { }
                    onSwitch { }
                }
                !dns.enabled() || !dns.hasCustomDnsSelected() -> {
                    setTexts(null)
                    switch(false)
                    arrow(null)
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                    }
                    onSwitch { enabled ->
                        when {
                            !dns.hasCustomDnsSelected() -> {
                                showSnack(R.string.menu_dns_select.res())
                                ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                                switch(false)
                            }
                            else -> {
                                entrypoint.onSwitchDnsEnabled(enabled)
                            }
                        }
                    }
                }
                else -> {
                    val item = dns.choices().first { it.active }
                    val id = if (item.id.startsWith("custom-dns:")) Base64.decode(item.id.removePrefix("custom-dns:"), Base64.NO_WRAP).toString(Charset.defaultCharset()) else item.id
                    val name = i18n.localisedOrNull("dns_${id}_name") ?: item.comment ?: id.capitalize()

                    setTexts(name)
                    switch(true)
                    arrow(null)
                    onTap {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                    }
                    onSwitch {
                        entrypoint.onSwitchAdblocking(it)
                    }
                }
            }
        }
        Unit
    }

    private fun ByteView.setTexts(name: String?) {
        when {
            simple && name == null -> {
                icon(R.drawable.ic_server.res(), color = R.color.switch_on.res())
                label(i18n.getString(R.string.slot_dns_name_disabled).res())
                state(null)
            }
            simple && name != null -> {
                icon(R.drawable.ic_server.res(), color = R.color.switch_on.res())
                label(i18n.getString(R.string.slot_dns_name).res())
                state(null)
            }
            name == null -> {
                icon(R.drawable.ic_server.res())
                label(R.string.home_dns_touch.res())
                state(R.string.slot_dns_name_disabled.res())
            }
            else -> {
                icon(R.drawable.ic_server.res(), color = R.color.switch_on.res())
                label(name.res())
                state(i18n.getString(R.string.slot_dns_name).res())
            }
        }
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

class MenuActiveDnsVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val tunnelState: Tunnel = ktx.di().instance(),
        private val i18n: I18n = ktx.di().instance(),
        private val dns: Dns = ktx.di().instance()
) : BitVB() {

    private var dnsServersChanged: IWhen? = null
    private var dnsEnabledChanged: IWhen? = null

    override fun attach(view: BitView) {
        dnsServersChanged = dns.dnsServers.doOnUiWhenSet().then(update)
        dnsEnabledChanged = dns.enabled.doOnUiWhenSet().then(update)
        update()
    }

    override fun detach(view: BitView) {
        dns.dnsServers.cancel(dnsServersChanged)
        dns.enabled.cancel(dnsEnabledChanged)
    }

    private val update = {
        view?.run {
            if (!tunnelState.enabled()) {
                label(R.string.home_blokada_disabled.res())
                icon(R.drawable.ic_server.res())
                switch(null)
                onSwitch {}
            } else {
                val item = dns.choices().firstOrNull() { it.active }
                if (item != null) {
                    val id = if (item.id.startsWith("custom-dns:")) Base64.decode(item.id.removePrefix("custom-dns:"), Base64.NO_WRAP).toString(Charset.defaultCharset()) else item.id
                    val name = i18n.localisedOrNull("dns_${id}_name") ?: item.comment
                    ?: id.capitalize()

                    if (dns.enabled() && dns.hasCustomDnsSelected()) {
                        icon(R.drawable.ic_server.res(), color = R.color.switch_on.res())
                        label(i18n.getString(R.string.slot_dns_name, name).res())
                    } else {
                        icon(R.drawable.ic_server.res())
                        label(R.string.slot_dns_name_disabled.res())
                    }
                } else {
                    icon(R.drawable.ic_server.res())
                    label(R.string.slot_dns_name_disabled.res())
                }

                switch(dns.enabled())
                onSwitch { enabled ->
                    when {
                        enabled && !dns.hasCustomDnsSelected() -> {
                            showSnack(R.string.menu_dns_select.res())
                            ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                            switch(false)
                        }
                        else -> {
                            entrypoint.onSwitchDnsEnabled(enabled)
                        }
                    }
                }
            }

        }
        Unit
    }
}
