package core

import android.app.Activity
import android.util.Base64
import android.view.View
import com.github.salomonbrys.kodein.instance
import org.blokada.R
import java.net.InetSocketAddress

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

    private var servers = Array<InetSocketAddress?>(2) { null }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)

        val nameVB = EnterDnsNameVB(ktx, accepted = { name ->
            if (servers[0] != null && servers[1] != null) {
                val newDnsChoice = DnsChoice("custom-dns:" + Base64.encodeToString(name.toByteArray(), Base64.NO_WRAP), servers.filterNotNull())
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

        stepView.pages = listOf(
                ip1VB,
                ip2VB,
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
