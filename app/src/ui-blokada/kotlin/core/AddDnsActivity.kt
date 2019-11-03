package core

import android.app.Activity
import android.os.AsyncTask
import android.util.Base64
import android.view.View
import com.github.salomonbrys.kodein.instance
import org.blokada.R
import java.net.InetAddress
import java.net.InetSocketAddress
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

class AddDnsActivity : Activity() {

    private val stepView by lazy { findViewById<VBStepView>(R.id.view) }
    private val ktx = ktx("AddDnsActivity")

    private val dns by lazy { ktx.di().instance<Dns>() }

    private val servers = Array<String?>(2) { null }
    private var dotEnabled : Boolean = false
    private var dotHost : String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)

        val nameVB = EnterDnsNameVB(ktx, accepted = { name ->
            if (servers.all { it != null }) {
                val serverAddresses = servers.filterNotNull().mapNotNull { if (dotEnabled) getSslSocketAddress(it, dotHost) else getSocketAddress(it) }
                val newDnsChoice = DnsChoice("custom-dns:" + Base64.encodeToString(name.toByteArray(), Base64.NO_WRAP), serverAddresses, dotEnabled)
                if (!dns.choices().contains(newDnsChoice)) {
                    dns.choices %= dns.choices() + newDnsChoice
                }
                finish()
            }
        })

        val ip1VB = EnterIpVB(ktx, first = true, accepted = {
            servers[0] = it
            stepView.next()
        })

        val ip2VB = EnterIpVB(ktx, first = false, accepted = {
            servers[1] = it
            val serverAddresses = servers.filterNotNull().mapNotNull{ getSocketAddress(it) }
            nameVB.defaultName = printServers(serverAddresses)
            stepView.next()
        })

        val dotHostVB = EnterDotHostVB(ktx, servers, accepted = {
            dotHost = it
            dotEnabled = it.isNotEmpty()
            stepView.next()
        })

        stepView.pages = listOf(
                ip1VB,
                ip2VB,
                dotHostVB,
                nameVB
        )
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
        private var servers: Array<String?>,
        private val accepted: (String) -> Unit = {}
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
                        accepted(input)
                    }
                }
        )

        view.onInput = { it ->
            input = it
            val error = initialValidate(it, view)
            inputValid = error == null
            error
        }

        view.requestFocusOnEdit()
    }

    private fun initialValidate(input: String, view: SlotView): String? {
        asyncCheck?.cancel(true)
        if (input.isEmpty()) {
            return null
        }
        asyncCheck = HostnameCheck(input, ktx, complete = {
            inputValid = it == null
            view.setValidationError(if (inputValid) null else ktx.ctx.resources.getString(R.string.dns_edit_dot_error))
        })
        asyncCheck?.execute(servers)
        return ktx.ctx.resources.getString(R.string.dns_edit_dot_wait)
    }

    class HostnameCheck(val input : String, val ktx: AndroidKontext,
                        val complete: (Throwable?) -> Unit) : AsyncTask<Array<String?>, Void, Throwable?>() {
        override fun doInBackground(vararg params: Array<String?>?): Throwable? {
            val servers = params[0]!!

            try {
                for (server in servers.filterNotNull()) {
                    val socketAddress = getSslSocketAddress(server, input)
                    val socket = SSLSocketFactory.getDefault().createSocket() as SSLSocket
                    socket.connect(socketAddress, 1000)
                    if (!HttpsURLConnection.getDefaultHostnameVerifier().verify(input, socket.session)) {
                        throw SSLHandshakeException("Expected ${input}, found ${socket.session.peerPrincipal} ")
                    }
                    socket.close()
                }
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
    val (address, port) = getAddressAndPort(addressAndPort, 53)
    return InetSocketAddress(address, port)
}

fun getSslSocketAddress(addressAndPort : String, hostnameInput : String?) : InetSocketAddress? {
    val (address, port) = getAddressAndPort(addressAndPort, 853)
    val hostname = hostnameInput ?: address
    return InetSocketAddress(InetAddress.getByAddress(hostname, InetAddress.getByName(address).address), port)
}

fun getAddressAndPort(addressAndPort: String, defaultPort: Int) : Pair<String, Int> {
    var address = addressAndPort
    var port = defaultPort
    if (!addressAndPort.matches(Regex("^(?:(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\\.(?!\$)|\$)){4}\$"))) {
        val parts = addressAndPort.split(":")
        address = parts[0]
        port = parts[1].toInt()
    }
    return Pair(address, port)
}
