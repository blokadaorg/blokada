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
        private val dns: Dns = ktx.di().instance()
) : ByteVB() {

    private var dnsServersChanged: IWhen? = null
    private var dnsEnabledChanged: IWhen? = null

    override fun attach(view: ByteView) {
        dnsServersChanged = dns.dnsServers.doOnUiWhenSet().then(update)
        dnsEnabledChanged = dns.enabled.doOnUiWhenSet().then(update)
        update()
    }

    override fun detach(view: ByteView) {
        dns.dnsServers.cancel(dnsServersChanged)
        dns.enabled.cancel(dnsEnabledChanged)
    }

    private val update = {
        view?.run {
            val item = dns.choices().firstOrNull { it.active }
            if (item != null) {
                val id = if (item.id.startsWith("custom-dns:")) Base64.decode(item.id.removePrefix("custom-dns:"), Base64.NO_WRAP).toString(Charset.defaultCharset()) else item.id
                val name = i18n.localisedOrNull("dns_${id}_name") ?: item.comment ?: id.capitalize()

                if (dns.enabled() && dns.hasCustomDnsSelected()) {
                    setTexts(name)
                } else {
                    setTexts(null)
                }
            } else {
                setTexts(null)
            }

//            if (dns.enabled() && !dns.hasCustomDnsSelected()) {
//                Handler {
//                    ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
//                    true
//                }.sendEmptyMessageDelayed(0, 300)
//            }

            onTap {
                ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
            }
            switch(dns.enabled())
            onSwitch { enabled ->
                when {
                    enabled && !dns.hasCustomDnsSelected(checkEnabled = false) -> {
                        showSnack(R.string.menu_dns_select.res())
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                        switch(false)
                    }
                    else -> {
                        dns.enabled %= enabled
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
}

class MenuActiveDnsVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
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
            val item = dns.choices().firstOrNull() { it.active }
            if (item != null) {
                val id = if (item.id.startsWith("custom-dns:")) Base64.decode(item.id.removePrefix("custom-dns:"), Base64.NO_WRAP).toString(Charset.defaultCharset()) else item.id
                val name = i18n.localisedOrNull("dns_${id}_name") ?: item.comment ?: id.capitalize()

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
                    enabled && !dns.hasCustomDnsSelected(checkEnabled = false) -> {
                        showSnack(R.string.menu_dns_select.res())
                        ktx.emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                        switch(false)
                    }
                    else -> {
                        dns.enabled %= enabled
                    }
                }
            }

        }
        Unit
    }
}
