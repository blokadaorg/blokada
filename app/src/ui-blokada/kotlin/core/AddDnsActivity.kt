package core

import android.app.Activity
import android.os.AsyncTask
import android.util.Base64
import android.view.View
import com.github.salomonbrys.kodein.instance
import org.blokada.R
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.UnknownHostException
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLHandshakeException
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

interface Stepable {
    fun focus()
}

interface Backable {
    fun handleBackPressed(): Boolean
}

interface ListSection {
    fun setOnSelected(listener: (item: Navigable?) -> Unit)
    fun scrollToSelected()
    fun selectNext() {}
    fun selectPrevious() {}
    fun unselect() {}
}

interface Scrollable {
    fun setOnScroll(
            onScrollDown: () -> Unit = {},
            onScrollUp: () -> Unit = {},
            onScrollStopped: () -> Unit = {}
    )

    fun getScrollableView(): View
}

interface Navigable {
    fun up()
    fun down()
    fun left()
    fun right()
    fun enter()
    fun exit()
}

class AddDnsActivity : AbstractAddDnsActivity(false)

class AddDnsOverTlsActivity : AbstractAddDnsActivity(true)

abstract class AbstractAddDnsActivity(private val dotEnabled: Boolean) : Activity() {

    private val stepView by lazy { findViewById<VBStepView>(R.id.view) }
    private val ktx = ktx("AddDnsActivity")

    private val dns by lazy { ktx.di().instance<Dns>() }

    private val servers = Array<InetSocketAddress?>(2) { null }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)

        val nameVB = EnterDnsNameVB(ktx, accepted = { name ->
            if (servers.all { it != null }) {
                val newDnsChoice = DnsChoice("custom-dns:" + Base64.encodeToString(name.toByteArray(), Base64.NO_WRAP),
                        servers.filterNotNull(), dotEnabled)
                if (!dns.choices().contains(newDnsChoice)) {
                    dns.choices %= dns.choices() + newDnsChoice
                }
                finish()
            }
        })

        val ip1VB = EnterIpVB(ktx, first = true, accepted = {
            servers[0] = getSocketAddress(it)
            stepView.next()
        })

        val ip2VB = EnterIpVB(ktx, first = false, accepted = {
            servers[1] = getSocketAddress(it)
            nameVB.defaultName = printServers(servers.filterNotNull())
            stepView.next()
        })

        val dotHostVB = EnterDotHostVB(ktx, accepted = { input, validServers ->
            validServers.forEachIndexed{ index, server ->  servers[index] = server}
            nameVB.defaultName = input
            stepView.next()
        })

        stepView.pages = if (dotEnabled) {
            listOf(
                    dotHostVB,
                    nameVB
            )
        } else {
            listOf(
                    ip1VB,
                    ip2VB,
                    nameVB
            )
        }
    }
}

class EnterIpVB(
        private val ktx: AndroidKontext,
        private val accepted: (String) -> Unit = {},
        private val first: Boolean
) : SlotVB(), Stepable {

    private var input = ""
    private var inputValid = false
    private val inputRegex = Regex("^(?:(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\\.){3}(?:(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9]))(?::\\d{1,5})?$")

    private fun validate(input: String) = when {
        !input.matches(inputRegex) -> ktx.ctx.resources.getString(R.string.slot_enter_dns_error)
        else -> null
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(ktx.ctx.resources.getString(R.string.dns_edit_ip_label),
                description = ktx.ctx.resources.getString(if (first) {
                    R.string.dns_edit_ip1_enter
                } else {
                    R.string.dns_edit_ip2_enter
                }),
                action1 = Slot.Action(ktx.ctx.resources.getString(R.string.dns_edit_next)) {
                    if (inputValid) {
                        view.fold()
                        accepted(input)
                    }
                }
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

class EnterDotHostVB(
        private val ktx: AndroidKontext,
        private val accepted: (String, List<InetSocketAddress>) -> Unit
) : SlotVB(), Stepable {

    private var input = ""
    private var inputValid = false
    private var asyncCheck: HostnameCheck? = null

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(ktx.ctx.resources.getString(R.string.dns_edit_dot_label),
                description = ktx.ctx.resources.getString(R.string.dns_edit_dot_enter),
                action1 = Slot.Action(ktx.ctx.resources.getString(R.string.dns_edit_next)) {
                    if (inputValid) {
                        view.fold()
                        accepted(input, asyncCheck!!.validServers!!)
                    }
                }
        )

        view.onInput = { it ->
            input = it
            inputValid = false

            asyncCheck?.cancel(true)
            asyncCheck = HostnameCheck(input, ktx, complete = {
                inputValid = it == null
                view.setValidationError(if (inputValid) null else ktx.ctx.resources.getString(R.string.dns_edit_dot_error))
            })
            asyncCheck?.execute()

            ktx.ctx.resources.getString(R.string.dns_edit_dot_wait)
        }

        view.requestFocusOnEdit()
    }

    class HostnameCheck(val input : String, val ktx: AndroidKontext,
                        val complete: (Throwable?) -> Unit) : AsyncTask<Void, Void, Throwable?>() {
        var validServers: List<InetSocketAddress>? = null

        override fun doInBackground(vararg params: Void?): Throwable? {

            try {
                val servers = getSslSocketAddresses(input)
                if (servers.size != 2) {
                    throw UnknownHostException("Could not find address and fallback IP for hostname")
                }
                for (socketAddress in servers) {
                    val socket = SSLSocketFactory.getDefault().createSocket() as SSLSocket
                    socket.connect(socketAddress, 1000)
                    if (!HttpsURLConnection.getDefaultHostnameVerifier().verify(socketAddress.hostName, socket.session)) {
                        throw SSLHandshakeException("Expected ${socketAddress.hostName}, found ${socket.session.peerPrincipal} ")
                    }
                    socket.close()
                }
                this.validServers = servers
            } catch (e : Exception) {
                return e
            }
            return null
        }

        override fun onPostExecute(result: Throwable?) {
            super.onPostExecute(result)
            complete(result)
        }
    }

}

class EnterDnsNameVB(
        private val ktx: AndroidKontext,
        private val accepted: (String) -> Unit = {}
) : SlotVB(), Stepable {

    var defaultName: String = ""
    private var input = ""
    private var inputValid = false
    private val inputRegex = Regex("^[A-z0-9\\s.:,]+$")

    private fun validate(input: String) = when {
        !input.matches(inputRegex) -> ktx.ctx.resources.getString(R.string.dns_edit_name_error)
        else -> null
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(ktx.ctx.resources.getString(R.string.dns_edit_name_label),
                action1 = Slot.Action(ktx.ctx.resources.getString(R.string.dns_edit_last)) {
                    if (inputValid) {
                        view.fold()
                        accepted(input)
                    }
                },
                action2 = Slot.Action(ktx.ctx.resources.getString(R.string.dns_edit_name_default)) {
                    view.input = defaultName
                }
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

fun getSocketAddress(addressAndPort : String) : InetSocketAddress? {
    val (address, port) = splitDelimited(addressAndPort, 53)
    return InetSocketAddress(address, port)
}

fun getSslSocketAddresses(hostnameAndPort : String) : List<InetSocketAddress> {
    val (hostname, port) = splitDelimited(hostnameAndPort, 853)
    return InetAddress.getAllByName(hostname)
            .filterIsInstance<Inet4Address>()
            .map { InetSocketAddress(it, port) }
}

fun splitDelimited(input: String, defaultPort: Int): Pair<String, Int> {
    return if (input.contains(":")) {
        Pair(input.split(":")[0], input.split(":")[1].toInt())
    } else {
        Pair(input, defaultPort)
    }
}
