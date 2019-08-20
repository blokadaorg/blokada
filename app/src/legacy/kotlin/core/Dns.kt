package core

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.net.Uri
import android.text.Editable
import android.text.TextWatcher
import android.util.AttributeSet
import android.view.*
import android.widget.AutoCompleteTextView
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView
import androidx.viewpager.widget.PagerAdapter
import androidx.viewpager.widget.ViewPager
import com.github.salomonbrys.kodein.*
import filter.AFilterView
import gs.environment.*
import gs.property.*
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.runBlocking
import org.blokada.R
import org.pcap4j.packet.namednumber.UdpPort
import java.io.InputStreamReader
import java.net.InetAddress
import java.net.InetSocketAddress
import java.nio.charset.Charset
import java.util.Properties

fun newDnsModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<AddDialog>() with provider {
            AddDialog(ctx)
        }
        bind<GenerateDialog>() with provider {
            GenerateDialog(xx = lazy)
        }
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

val DASH_ID_DNS = "dns"

class Add(
        val ctx: Context,
        val dns: Dns = ctx.inject().instance(),
        val dialogProvider: () -> AddDialog = ctx.inject().provider()
) : Dash(
        "dns_add",
        R.drawable.ic_filter_add,
        onClick = {
            val dialog = dialogProvider()
            dialog.onSave = { newFilter ->
                if (!dns.choices().contains(newFilter))
                    dns.choices %= dns.choices() + newFilter
            }
            dialog.show(null)
            false
        }
) {}

class QuickActions(
        val xx: Environment,
        val dialogProvider: () -> GenerateDialog = xx().provider()
) : Dash(
        "dns_generate",
        R.drawable.ic_tune,
        onClick = {
            val dialog = dialogProvider()
            dialog.show()
            false
        }
)

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

class DnsActor(
        initialFilter: DnsChoice,
        private val v: AFilterView
) {
    private val dialog by lazy { AddDialog(v.context) }
    private val dns by lazy { v.context.inject().instance<Dns>() }
    private val ic by lazy { v.resources.getDrawable(R.drawable.ic_server) }
    private val i18n by lazy { v.context.inject().instance<I18n>() }

    var filter = initialFilter
        set(value) {
            field = value
            update()
        }

    init {
        update()
        v.setOnClickListener ret@ {
            dialog.onSave = { newFilter ->
                if (filter.id == "default" && !dns.choices().contains(newFilter))
                    dns.choices %= dns.choices() + newFilter
                else dns.choices %= dns.choices().map { if (it == filter) newFilter else it }
            }
            if (filter.id == "default") dialog.show(null)
            else dialog.show(filter)
        }
        v.onDelete = {
            if (filter.id != "default") dns.choices %= dns.choices().minus(filter)
        }
        v.showDelete = true
        v.onSwitched = { active ->
            if (!active) {
                dns.choices().first().active = true
            } else {
                dns.choices().filter { it.active }.forEach { it.active = false }
            }
            filter.active = active
            dns.choices %= dns.choices()
        }
    }

    private fun update() {
        val id = if (filter.id.startsWith("custom")) "custom" else filter.id
        v.name = i18n.localisedOrNull("dns_${id}_name") ?: id.capitalize()
        v.description = filter.comment ?: i18n.localisedOrNull("dns_${id}_comment")
        v.source = {
            val s = if (filter.servers.isNotEmpty()) filter.servers else dns.dnsServers()
            printServers(s)
        }()

        v.active = filter.active

        v.multiple = false
        v.icon = ic
        v.iconForceFilter = true

        // Credit source
        if (filter.credit != null) {
            v.credit = try {
                Intent(Intent.ACTION_VIEW, Uri.parse(filter.credit))
            } catch (e: Exception) {
                null
            }
            v.credit?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        } else v.credit = null

    }
}

class AddDialog(
        private val ctx: Context
) {
    var onSave = { filter: DnsChoice -> }

    private val activity by lazy { ctx.inject().instance<ComponentProvider<Activity>>().get() }
    private val j by lazy { ctx.inject().instance<Journal>() }
    private val themedContext by lazy { ContextThemeWrapper(ctx, R.style.BlokadaColors_Dialog) }
    private val view = LayoutInflater.from(themedContext)
            .inflate(R.layout.view_dnstab, null, false) as DnsAddTabView
    private val dialog: AlertDialog

    init {
        val d = AlertDialog.Builder(activity)
        d.setView(view)
        d.setPositiveButton(R.string.filter_edit_save, { dia, int -> })
        d.setNegativeButton(R.string.filter_edit_cancel, { dia, int -> })
        dialog = d.create()
    }

    fun show(filter: DnsChoice?) {
        view.appView.reset()
        if (filter != null) {
            val s = filter.servers.map { it.getHostString() + ( if(it.getPort()!=53) ":" + it.getPort().toString() else "" ) }.toMutableList()
            view.appView.server1 = s.first()
            view.appView.server2 = s.getOrElse(1, {""})
            view.appView.correct = true
            view.appView.comment = filter.comment ?: ""
        }

        if (dialog.isShowing) return
        try {
            dialog.show()
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener { handleSave(filter) }
            dialog.window.clearFlags(
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
            )
        } catch (e: Exception) {
            j.log(e)
        }
    }

    private fun handleSave(filter: DnsChoice?) {
        if (!view.appView.correct) view.appView.showError = true
        else {
            val s = listOf(view.appView.server1, view.appView.server2).filter { it.isNotBlank() }.map {
                runBlocking { async {
                    ipStringToAddress(it)
                }.await() }
            }
            dialog.dismiss()
            onSave(DnsChoice(
                    id = filter?.id ?: "custom_" + s.toString(),
                    servers = s,
                    active = false,
                    comment = if (view.appView.comment.isNotBlank()) view.appView.comment else null
            ))
            view.appView.correct = true
        }
    }
}

class DnsAddView(
        ctx: Context,
        attributeSet: AttributeSet
) : ScrollView(ctx, attributeSet) {

    var server1 = ""
        get() {
            return field.trim()
        }
        set(value) {
            field = value
            if (editView.text.toString() != value) {
                editView.setText(value)
                editView.setSelection(value.length)
            }
            correct = isTextCorrect(value, forceNotEmpty = true)
            updateError()
        }

    var server2 = ""
        get() {
            return field.trim()
        }
        set(value) {
            field = value
            if (editView2.text.toString() != value) {
                editView2.setText(value)
                editView2.setSelection(value.length)
            }
            correct = isTextCorrect(value)
            updateError()
        }

    var comment = ""
        get() {
            return field.trim()
        }
        set(value) {
            field = value
            if (commentView.text.toString() != value) {
                commentView.setText(value)
                commentView.setSelection(value.length)
            }

            if (value.isNotEmpty()) {
                commentReadView.text = value
            } else {
                commentReadView.text = resources.getString(R.string.filter_edit_comments_none)
            }
        }

    var showError = false
        set(value) {
            field = value
            updateError()
        }

    var correct = false
        set(value) {
            field = value
            updateError()
        }

    fun reset() {
        server1 = ""
        server2 = ""
        comment = ""
        showError = false
        correct = false
        commentView.visibility = View.GONE
        commentReadView.visibility = View.VISIBLE
    }

    private val editView by lazy { findViewById(R.id.filter_edit) as AutoCompleteTextView }
    private val editView2 by lazy { findViewById(R.id.filter_edit2) as AutoCompleteTextView }
    private val errorView by lazy { findViewById(R.id.filter_error) as ViewGroup }
    private val commentView by lazy { findViewById(R.id.filter_comment) as EditText }
    private val commentReadView by lazy { findViewById(R.id.filter_comment_read) as TextView }

    override fun onFinishInflate() {
        super.onFinishInflate()
        updateError()

        editView.addTextChangedListener(object : TextWatcher {
            override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
                server1 = s.toString()
            }

            override fun afterTextChanged(s: Editable) {}
            override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {}
        })

        editView2.addTextChangedListener(object : TextWatcher {
            override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
                server2 = s.toString()
            }

            override fun afterTextChanged(s: Editable) {}
            override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {}
        })

        commentReadView.setOnClickListener {
            commentReadView.visibility = View.GONE
            commentView.visibility = View.VISIBLE
            commentView.requestFocus()
        }

        commentView.setOnFocusChangeListener { view, focused ->
            if (!focused) {
                commentView.visibility = View.GONE
                commentReadView.visibility = View.VISIBLE
            }
        }

        commentView.addTextChangedListener(object : TextWatcher {
            override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
                comment = s.toString()
            }

            override fun afterTextChanged(s: Editable) {}
            override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {}
        })
    }

    private fun updateError() {
        if (showError && !correct) {
            errorView.visibility = View.VISIBLE
        } else {
            errorView.visibility = View.GONE
        }
    }

    private fun isTextCorrect(s: String, forceNotEmpty: Boolean = false): Boolean {
        return when {
            forceNotEmpty && s.isBlank() -> false
            s.isBlank() -> true
            else -> {
                try {
                    ipStringToAddress(s)
                    true
                } catch (e: Exception) { false }
            }
        }
    }
}

class DnsAddTabView(
        ctx: Context,
        attributeSet: AttributeSet
) : android.widget.FrameLayout(ctx, attributeSet) {

    val appView by lazy {
        android.view.LayoutInflater.from(context).inflate(R.layout.view_dnsadd, pager, false)
                as DnsAddView
    }

    private var ready = false

    private val pager by lazy { findViewById(R.id.filters_pager) as ViewPager }

    override fun onFinishInflate() {
        super.onFinishInflate()

        ready = true
        pager.offscreenPageLimit = 3
        pager.adapter = object : PagerAdapter() {

            override fun instantiateItem(container: android.view.ViewGroup, position: Int): Any {
                container.addView(appView)
                return appView
            }

            override fun destroyItem(container: android.view.ViewGroup, position: Int, obj: Any) {
                container.removeView(obj as android.view.View)
            }

            override fun getPageTitle(position: Int): CharSequence {
                return context.getString(R.string.dns_tab_v4)
            }

            override fun getItemPosition(obj: Any): Int {
                return POSITION_NONE // To reload on notifyDataSetChanged()
            }

            override fun getCount(): Int { return 1 }
            override fun isViewFromObject(view: android.view.View, obj: Any): Boolean { return view == obj }
        }
    }

}
