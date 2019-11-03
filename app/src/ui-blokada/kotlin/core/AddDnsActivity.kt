package core

import android.app.Activity
import android.os.AsyncTask
import android.util.Base64
import android.view.View
import com.github.salomonbrys.kodein.instance
import gs.environment.getDnsServers
import kotlinx.coroutines.experimental.async
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

    private val servers = Array<InetSocketAddress?>(2) { null }
    private var dotEnabled : Boolean = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)

        val nameVB = EnterDnsNameVB(ktx, accepted = { name ->
            if (servers[0] != null && servers[1] != null) {
                val newDnsChoice = DnsChoice("custom-dns:" + Base64.encodeToString(name.toByteArray(), Base64.NO_WRAP), servers.filterNotNull(), dotEnabled)
                if (!dns.choices().contains(newDnsChoice)) {
                    dns.choices %= dns.choices() + newDnsChoice
                }
                finish()
            }
        })

        val ip1VB = EnterIpVB(ktx, first = true, accepted = {
            servers[0] = if (it.matches(Regex("^(?:(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\\.(?!\$)|\$)){4}\$"))) {
                InetSocketAddress(it, 53)
            } else {
                val parts = it.split(":")
                InetSocketAddress(parts[0], parts[1].toInt())
            }
            stepView.next()
        })

        val ip2VB = EnterIpVB(ktx, first = false, accepted = {
            servers[1] = if (it.matches(Regex("^(?:(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\\.(?!\$)|\$)){4}\$"))) {
                InetSocketAddress(it, 53)
            } else {
                val parts = it.split(":")
                InetSocketAddress(parts[0], parts[1].toInt())
            }
            nameVB.defaultName = printServers(servers.filterNotNull())
            stepView.next()
        })

        val dotHostVB = EnterDotHostVB(ktx, servers, accepted = {
            if (it.isEmpty()) {
                dotEnabled = false
            } else {
                dotEnabled = true
                var host = it
                var portString = "853"
                if (it.contains(":")) {
                    val parts = it.split(":")
                    host = parts[0]
                    portString = parts[1]
                }
                var port = portString.toInt()
                for (i in servers.indices) {
                    if (servers[i] != null) {
                        servers[i] = InetSocketAddress(InetAddress.getByAddress(host, servers[i]!!.address.address), port)
                    }
                }
            }
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
        private var servers: Array<InetSocketAddress?>,
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
                        val complete: (Throwable?) -> Unit) : AsyncTask<Array<InetSocketAddress?>, Void, Throwable?>() {
        override fun doInBackground(vararg params: Array<InetSocketAddress?>?): Throwable? {
            val servers = params[0]!!

            try {
                for (server in servers) {
                    val hostname = (if (input.contains(":")) input.split(":")[0] else input)
                    val port = (if (input.contains(":")) input.split(":")[1].toInt() else 853)
                    val socket = SSLSocketFactory.getDefault().createSocket() as SSLSocket
                    socket.connect(InetSocketAddress(InetAddress.getByAddress(hostname, server!!.address.address), port), 1000)
                    if (!HttpsURLConnection.getDefaultHostnameVerifier().verify(hostname, socket.session)) {
                        throw SSLHandshakeException("Expected ${hostname}, found ${socket.session.peerPrincipal} ")
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
