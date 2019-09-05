package core

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.DialogInterface
import android.view.WindowManager
import com.github.salomonbrys.kodein.*
import gs.environment.*
import gs.property.*
import org.blokada.R
import org.pcap4j.packet.namednumber.UdpPort
import java.io.InputStreamReader
import java.net.InetAddress
import java.net.InetSocketAddress
import java.nio.charset.Charset
import java.util.Properties

fun newDnsModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Dns>() with singleton {
            DnsImpl(with("gscore").instance(), lazy)
        }
        bind<DnsLocalisedFetcher>() with singleton {
            DnsLocalisedFetcher(xx = lazy)
        }
        onReady {
            val s: Tunnel = instance()

            // Reload engine in case dns selection changes
            val dns: Dns = instance()
            var currentDns: DnsChoice? = null
            dns.choices.doWhenSet().then {
                val newChoice = dns.choices().firstOrNull { it.active }
                if (newChoice != null && newChoice != currentDns) {
                    currentDns = newChoice

                    if (!s.enabled()) {
                    } else if (s.active()) {
                        s.restart %= true
                        s.active %= false
                    } else {
                        s.retries.refresh()
                        s.restart %= false
                        s.active %= true
                    }
                }
            }

        }
    }
}

abstract class Dns {
    abstract val choices: IProperty<List<DnsChoice>>
    abstract val dnsServers: IProperty<List<InetSocketAddress>>
    abstract val enabled: IProperty<Boolean>
    abstract fun hasCustomDnsSelected(checkEnabled: Boolean = true): Boolean
}

val FALLBACK_DNS = listOf(
        InetSocketAddress(InetAddress.getByAddress(byteArrayOf(1, 1, 1, 1)), 53),
        InetSocketAddress(InetAddress.getByAddress(byteArrayOf(1, 0, 0, 1)), 53)
)

class DnsImpl(
        w: Worker,
        xx: Environment,
        pages: Pages = xx().instance(),
        serialiser: DnsSerialiser = DnsSerialiser(),
        fetcher: DnsLocalisedFetcher = xx().instance(),
        d: Device = xx().instance(),
        ctx: Context = xx().instance()
) : Dns() {

    override fun hasCustomDnsSelected(checkEnabled: Boolean): Boolean {
        return choices().firstOrNull { it.id != "default" && it.active } != null && (!checkEnabled or enabled())
    }

    private val refresh = { it: List<DnsChoice> ->
        val ktx = "dns:refresh".ktx()
        ktx.v("refresh start", pages.dns())
        var builtInDns = listOf(DnsChoice("default", emptyList(), active = false))
        builtInDns += try {
            serialiser.deserialise(loadGzip(openUrl(pages.dns(), 10000)))
        } catch (e: Exception) {
            try {
                // Try again in case it randomly failed
                Thread.sleep(3000)
                serialiser.deserialise(loadGzip(openUrl(pages.dns(), 10000)))
            } catch (e: Exception) {
                ktx.e("failed to refresh dns", e)
                emptyList<DnsChoice>()
            }
        }
        ktx.v("got ${builtInDns.size} dns server entries")

        val newDns = if (it.isEmpty()) {
            builtInDns
        } else {
            it.map { dns ->
                val new = builtInDns.find { it == dns }
                if (new != null) {
                    new.active = dns.active
                    new.servers = dns.servers
                    new
                } else dns
            }.plus(builtInDns.minus(it))
        }

        // Make sure only one is active
        val activeCount = newDns.count { it.active }
        if (activeCount != 1) {
            newDns.forEach { it.active = false }
            newDns.first().active = true
        }

        ktx.v("refresh done")
        fetcher.fetch()
        newDns
    }

    override val choices = newPersistedProperty(w, DnsChoicePersistence(xx),
            zeroValue = { listOf() },
            refresh = refresh,
            shouldRefresh = { it.size <= 1 })

    override val dnsServers = newProperty(w, {
        val d = if (enabled()) choices().firstOrNull { it.active } else null
        if (d?.servers?.isEmpty() ?: true) getDnsServers(ctx)
        else d?.servers!!
    })

    override val enabled = newPersistedProperty(w, BasicPersistence(xx, "dnsEnabled"), { false })

    init {
        pages.dns.doWhenSet().then {
            choices.refresh()
        }

        choices.doOnUiWhenSet().then {
            dnsServers.refresh()
        }
        enabled.doOnUiWhenChanged(withInit = true).then {
            dnsServers.refresh()
        }
        d.connected.doOnUiWhenSet().then {
            dnsServers.refresh()
        }

        dnsServers.doWhenChanged(withInit = true).then {
            val current = dnsServers()
            if (tunnel.Persistence.config.load(ctx.ktx()).dnsFallback && isLocalServers(current)) {
                dnsServers %= FALLBACK_DNS
                "dns".ktx().w("local DNS detected, setting CloudFlare as workaround")
            }
        }
    }

    private fun isLocalServers(servers: List<InetSocketAddress>): Boolean {
        return when {
            servers.isEmpty() -> true
            servers.first().address.isLinkLocalAddress -> true
            servers.first().address.isSiteLocalAddress -> true
            servers.first().address.isLoopbackAddress -> true
            else -> false
        }
    }
}

data class DnsChoice(
        val id: String,
        var servers: List<InetSocketAddress>,
        var active: Boolean = false,
        var ipv6: Boolean = false,
        val credit: String? = null,
        val comment: String? = null
) {
    override fun hashCode(): Int {
        return id.hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (other !is DnsChoice) return false
        return id.equals(other.id)
    }
}

class DnsChoicePersistence(xx: Environment) : PersistenceWithSerialiser<List<DnsChoice>>(xx) {

    val p by lazy { serialiser("dns") }
    val s by lazy { DnsSerialiser() }

    override fun read(current: List<DnsChoice>): List<DnsChoice> {
        val dns = s.deserialise(p.getString("dns", "").split("^"))
        return if (dns.isNotEmpty()) dns else current
    }

    override fun write(source: List<DnsChoice>) {
        val e = p.edit()
        e.putInt("migratedVersion", 1)
        e.putString("dns", s.serialise(source).joinToString("^"))
        e.apply()
    }

}

private fun addressToIpString(it: InetSocketAddress) =
        it.hostString + ( if (it.port != 53) ":" + it.port.toString() else "" )

private fun ipStringToAddress(it: String) = {
    val hostport = it.split(':', limit = 2)
    val host = hostport[0]
    val port = ( if (hostport.size == 2) hostport[1] else "").toIntOrNull() ?: UdpPort.DOMAIN.valueAsInt()
    InetSocketAddress(InetAddress.getByName(host), port)
}()

class DnsSerialiser {
    fun serialise(dns: List<DnsChoice>): List<String> {
        var i = 0
        return dns.map {
            val active = if (it.active) "active" else "inactive"
            val ipv6 = if (it.ipv6) "ipv6" else "ipv4"
            val servers = it.servers.map { addressToIpString(it) }.joinToString(";")
            val credit = it.credit ?: ""
            val comment = it.comment ?: ""

            "${i++}\n${it.id}\n${active}\n${ipv6}\n${servers}\n${credit}\n${comment}"
        }.flatMap { it.split("\n") }
    }

    fun deserialise(source: List<String>): List<DnsChoice> {
        if (source.size <= 1) return emptyList()
        val dns = source.asSequence().batch(7).map { entry ->
            entry[0].toInt() to try {
                val id = entry[1]
                val active = entry[2] == "active"
                val ipv6 = entry[3] == "ipv6"
                val servers = entry[4].split(";").filter { it.isNotBlank() }.map { ipStringToAddress(it) }
                val credit = if (entry[5].isNotBlank()) entry[5] else null
                val comment = if (entry[6].isNotBlank()) entry[6] else null

                DnsChoice(id, servers, active, ipv6, credit, comment)
            } catch (e: Exception) {
                null
            }
        }.toList().sortedBy { it.first }.map { it.second }.filterNotNull()
        return dns
    }
}

class DnsLocalisedFetcher(
        private val xx: Environment,
        private val i18n: I18n = xx().instance(),
        private val pages: Pages = xx().instance(),
        private val j: Journal = xx().instance()
) {
    init {
        i18n.locale.doWhenChanged().then { fetch() }
    }

    fun fetch() {
        j.log("dns: fetch strings: start ${pages.dnsStrings()}")
        val prop = Properties()
        try {
            prop.load(InputStreamReader(openUrl(pages.dnsStrings(), 10000)().getInputStream(),
                    Charset.forName("UTF-8")))
            prop.stringPropertyNames().iterator().forEach {
                i18n.set("dns_$it", prop.getProperty(it))
            }
        } catch (e: Exception) {
            j.log("dns: fetch strings crash", e)
        }
        j.log("dns: fetch strings: done")
    }
}

class GenerateDialog(
        private val xx: Environment,
        private val ctx: Context = xx().instance(),
        private val dns: Dns = xx().instance()
) {

    private val activity by lazy { xx().instance<ComponentProvider<Activity>>().get() }
    private val j by lazy { ctx.inject().instance<Journal>() }
    private val dialog: AlertDialog
    private var which: Int = 0

    init {
        val d = AlertDialog.Builder(activity)
        d.setTitle(R.string.filter_generate_title)
        val options = arrayOf(
                ctx.getString(R.string.dns_generate_refetch),
                ctx.getString(R.string.dns_generate_defaults)
        )
        d.setSingleChoiceItems(options, which, object : DialogInterface.OnClickListener {
            override fun onClick(dialog: DialogInterface?, which: Int) {
                this@GenerateDialog.which = which
            }
        })
        d.setPositiveButton(R.string.filter_edit_do, { dia, int -> })
        d.setNegativeButton(R.string.filter_edit_cancel, { dia, int -> })
        dialog = d.create()
    }

    fun show() {
        if (dialog.isShowing) return
        try {
            dialog.show()
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener { handleSave() }
            dialog.window.clearFlags(
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
            )
        } catch (e: Exception) {
            j.log(e)
        }
    }

    private fun handleSave() {
        when (which) {
            0 -> {
                dns.choices.refresh(force = true)
            }
            1 -> {
                dns.choices %= emptyList()
                dns.choices.refresh()
            }
        }
        dialog.dismiss()
    }

}

fun printServers(s: List<InetSocketAddress>): String {
    return s.map { addressToIpString(it) }.joinToString (", ")
}

