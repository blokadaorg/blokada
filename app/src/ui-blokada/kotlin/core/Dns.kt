package core

import android.content.Context
import blocka.BlockaVpnState
import com.github.salomonbrys.kodein.*
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.Worker
import gs.environment.getDnsServers
import gs.property.*
import org.blokada.R
import org.json.JSONArray
import org.json.JSONException
import org.pcap4j.packet.namednumber.UdpPort
import tunnel.TunnelConfig
import java.io.InputStreamReader
import java.net.InetAddress
import java.net.InetSocketAddress
import java.nio.charset.Charset
import java.util.*

fun newDnsModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Dns>() with singleton {
            DnsImpl(with("gscore").instance(), lazy)
        }
        bind<DnsLocalisedFetcher>() with singleton {
            DnsLocalisedFetcher(xx = lazy)
        }
    }
}

abstract class Dns {
    abstract val choices: IProperty<List<DnsChoice>>
    abstract val dnsServers: IProperty<List<InetSocketAddress>>
    abstract val dotEnabled: IProperty<Boolean>
    abstract val enabled: IProperty<Boolean>
    abstract fun hasCustomDnsSelected(): Boolean

    fun getIcon(): Int {
        return getIcon(dotEnabled.invoke())
    }
}

private val FALLBACK_DNS = listOf(
        InetSocketAddress(InetAddress.getByAddress(byteArrayOf(1, 1, 1, 1)), 53),
        InetSocketAddress(InetAddress.getByAddress(byteArrayOf(8, 8, 8, 8)), 53)
)

class DnsImpl(
        w: Worker,
        xx: Environment,
        pages: Pages = xx().instance(),
        serialiser: JsonDnsSerialiser = JsonDnsSerialiser(),
        fetcher: DnsLocalisedFetcher = xx().instance(),
        d: Device = xx().instance(),
        ctx: Context = xx().instance()
) : Dns() {

    override fun hasCustomDnsSelected(): Boolean {
        return choices().firstOrNull { it.id != "default" && it.active } != null
    }

    private val refresh = { it: List<DnsChoice> ->
        val ktx = "dns:refresh".ktx()
        ktx.v("refresh start", pages.dns())
        var builtInDns = listOf(DnsChoice("default", emptyList(), false, active = false))
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
                    new.dotEnabled = dns.dotEnabled
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
        val blockaVpnState = get(BlockaVpnState::class.java)
        val useDnsFallback = get(TunnelConfig::class.java).dnsFallback
        val choice = if(enabled()) choices().firstOrNull { it.active } else null
        val proposed = choice?.servers ?: getDnsServers(ctx)
        when {
            blockaVpnState.enabled && (choice == null || choice.id == "default") -> {
                // We can't tell if default DNS servers will be reachable in the tunnel. Safely default.
                v("using fallback DNS under Blocka VPN")
                FALLBACK_DNS
            }
            blockaVpnState.enabled && choice != null && isLocalServers(choice.servers) -> {
                // We assume user knows what they're selecting, but since we can easily check for local..
                v("using fallback DNS because local DNS selected and under Blocka VPN", choice.servers)
                FALLBACK_DNS
            }
            useDnsFallback && isLocalServers(proposed) -> {
                v("using fallback DNS because local DNS selected / default", proposed)
                FALLBACK_DNS
            }
            else -> proposed
        }
    })

    override val dotEnabled = newProperty(w, {
        val choice = if(enabled()) choices().firstOrNull { it.active } else null
        choice?.dotEnabled ?: false
    })

    override val enabled = newPersistedProperty(w, BasicPersistence(xx, "dnsEnabled"), { false })

    init {
        pages.dns.doWhenSet().then {
            choices.refresh()
        }

        choices.doOnUiWhenSet().then {
            dnsServers.refresh()
            dotEnabled.refresh()
        }
        enabled.doOnUiWhenChanged(withInit = true).then {
            dnsServers.refresh()
            dotEnabled.refresh()
        }
        d.connected.doOnUiWhenSet().then {
            dnsServers.refresh()
            dotEnabled.refresh()
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
        var dotEnabled: Boolean,
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

    fun getIcon(): Int {
        return getIcon(dotEnabled)
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

private fun addressToIpString(it: InetSocketAddress, dotEnabled: Boolean) =
        it.address.hostAddress + ( if (it.port != 53) ":" + it.port.toString() else "" ) + ( if (dotEnabled) "#" + it.hostName else "" )


private fun ipStringToAddress(ipString: String) = {
    val ipPortHost = ipString.split('#', limit = 2)
    val host = (if (ipPortHost.size > 1) ipPortHost[1] else "")
    ipStringToAddress(ipPortHost[0], host)
}()

private fun ipStringToAddress(ipString: String, host: String) = {
    val ipPort = ipString.split(':', limit = 2)
    val ip = ipPort[0]
    val port = ( if (ipPort.size == 2) ipPort[1] else "").toIntOrNull() ?: UdpPort.DOMAIN.valueAsInt()
    if (host.isNotEmpty()) {
        InetSocketAddress(InetAddress.getByAddress(host, InetAddress.getByName(ip).address), port)
    } else {
        InetSocketAddress(InetAddress.getByName(ip), port)
    }
}()

private fun ipStringToDotEnabled(it: String): Boolean {
    val hostIpPort = it.split("#", limit = 2)
    val host = (if (hostIpPort.size > 1) hostIpPort[1] else "")
    return host.isNotEmpty()
}

class DnsSerialiser {
    fun serialise(dns: List<DnsChoice>): List<String> {
        var i = 0
        return dns.map {
            val active = if (it.active) "active" else "inactive"
            val ipv6 = if (it.ipv6) "ipv6" else "ipv4"
            val dotEnabled = it.dotEnabled
            val servers = it.servers.map { addressToIpString(it, dotEnabled) }.joinToString(";")
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
                val dotEnabled = ipStringToDotEnabled(entry[4])
                val credit = if (entry[5].isNotBlank()) entry[5] else null
                val comment = if (entry[6].isNotBlank()) entry[6] else null

                DnsChoice(id, servers, dotEnabled, active, ipv6, credit, comment)
            } catch (e: Exception) {
                null
            }
        }.toList().sortedBy { it.first }.map { it.second }.filterNotNull()
        return dns
    }
}

class JsonDnsSerialiser {
    fun deserialise(repo: String): List<DnsChoice> {
        val dnsChoices = emptySet<Pair<Int, DnsChoice>>().toMutableSet()
        try {
            val jsonChoices = JSONArray(repo)
            for (i in 0 until jsonChoices.length()) {
                val jsonDnsChoice = jsonChoices.getJSONObject(i)
                var dotEnabled = false
                val jsonServers = jsonDnsChoice.getJSONArray("servers")
                val servers = List(jsonServers.length()) {
                    val jsonServer = jsonServers.getJSONObject(it)
                    val dotHostname = jsonServer.optString("dot")
                    val ipAndPort = jsonServer.getString("ip")
                    dotEnabled = dotEnabled || dotHostname.isNotEmpty()
                    ipStringToAddress(ipAndPort, dotHostname)
                }
                val comment = jsonDnsChoice.getString("comment")
                val credit = jsonDnsChoice.getString("credit")
                dnsChoices.add(jsonDnsChoice.getInt("index") to DnsChoice(
                        jsonDnsChoice.getString("id"),
                        servers,
                        dotEnabled,
                        jsonDnsChoice.getBoolean("active"),
                        jsonDnsChoice.getBoolean("usesIpv6"),
                        if(jsonDnsChoice.isNull("credit") || credit.isEmpty()) null else credit,
                        if(jsonDnsChoice.isNull("comment") || comment.isEmpty()) null else comment
                ))
            }

        } catch (e: JSONException) {
            v("Json parsing error: " + e.message)
            v("JSON-data was:$repo")
            e(e)
        }

        return dnsChoices.toList().sortedBy { it.first }.map { it.second }
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

fun printServers(s: List<InetSocketAddress>): String {
    return s.map { addressToIpString(it, false) }.joinToString (", ")
}

private fun getIcon(dotEnabled: Boolean) : Int {
    return if (dotEnabled) {
        // TODO: new icon for DNS over TLS?
        R.drawable.ic_shield_key_outline
    } else {
        R.drawable.ic_server
    }
}

