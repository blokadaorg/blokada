package core.bits

import android.content.Context
import android.util.Base64
import blocka.BlockaVpnState
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
            arrow(null)
            onTap {
                ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
            }
            onSwitch { enable ->
                when {
                    !dns.hasCustomDnsSelected() -> {
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                        switch(false)
                        showSnack(R.string.menu_dns_select.res())
                    }
                    else -> {
                        if (enable && !tunnelEvents.enabled()) tunnelEvents.enabled %= true
                        entrypoint.onSwitchDnsEnabled(enable)
                    }
                }
            }

            var name: String? = null
            try {
                val item = dns.choices().first { it.active }
                val id = if (item.id.startsWith("custom-dns:")) Base64.decode(item.id.removePrefix("custom-dns:"), Base64.NO_WRAP).toString(Charset.defaultCharset()) else item.id
                name = i18n.localisedOrNull("dns_${id}_name") ?: item.comment ?: id.capitalize()
                name = if (dns.enabled() && dns.hasCustomDnsSelected() && tunnelEvents.enabled()) name else null
            } catch (e: Exception) {}

            setTexts(name)
            switch(name != null)
        }
        Unit
    }

    private fun ByteView.setTexts(name: String?) {
        when {
            name == null -> {
                icon(R.drawable.ic_server.res())
                label(R.string.slot_dns_name_disabled.res())
                state(R.string.home_touch.res())
            }
            else -> {
                icon(R.drawable.ic_server.res(), color = R.color.switch_on.res())
                label(name.res())
                val vpn = get(BlockaVpnState::class.java).enabled
                if (vpn) state(R.string.slot_dns_name_private.res()) else state(null)
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
            onSwitch { enabled ->
                when {
                    enabled && !dns.hasCustomDnsSelected() -> {
                        showSnack(R.string.menu_dns_select.res())
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                        switch(false)
                    }
                    else -> {
                        if (enabled && !tunnelState.enabled()) tunnelState.enabled %= true
                        entrypoint.onSwitchDnsEnabled(enabled)
                    }
                }
            }

            if (!tunnelState.enabled()) {
                label(R.string.home_blokada_disabled.res())
                icon(R.drawable.ic_server.res())
                switch(false)
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
            }

        }
        Unit
    }
}
