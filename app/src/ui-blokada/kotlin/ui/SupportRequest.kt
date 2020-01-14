package ui

import android.app.Activity
import android.content.Context
import blocka.CurrentAccount
import blocka.blokadaUserAgent
import com.github.salomonbrys.kodein.instance
import core.*
import core.Register.set
import gs.property.I18n
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.delay
import org.blokada.BuildConfig
import org.blokada.R
import zendesk.core.AnonymousIdentity
import zendesk.core.Zendesk
import zendesk.support.CustomField
import zendesk.support.Support
import zendesk.support.request.RequestActivity
import zendesk.support.requestlist.RequestListActivity
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

private var zendeskInited = false

private fun initZendesk(context: Context) {
    val userInfo = get(SupportUserInfo::class.java)

    Zendesk.INSTANCE.init(context, "https://blokada.zendesk.com",
            "2e7478d72ede322570d36115f1037cefa6de491ec2d6eafd",
            "mobile_sdk_client_814b0a97bc235165f010")
    Support.INSTANCE.init(Zendesk.INSTANCE)

    val identity = AnonymousIdentity.Builder().withNameIdentifier(userInfo.getNameOrDefault())
    userInfo.email?.run { identity.withEmailIdentifier(this) }
    Zendesk.INSTANCE.setIdentity(identity.build())
}

data class SupportUserInfo(val name: String?, val email: String?, val hasTickets: Boolean = false) {

    fun getNameOrDefault() = name ?: email?.substringBefore("@") ?: "Guest"

    fun hasChanged(name: String?, email: String?) = when {
        this.name == null && this.email == null -> true
        this.name != name || this.email != email -> true
        else -> false
    }
}

fun registerPersistenceForSupportUserInfo() {
    Register.sourceFor(SupportUserInfo::class.java, default = SupportUserInfo(null, null),
            source = PaperSource("support-user"))
}

class SupportRequestActivity : Activity() {

    private val stepView by lazy { findViewById<VBStepView>(R.id.view) }
    private val ktx = ktx("SupportRequest")

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        //initGlobal(this, failsafe = true)

        if (!zendeskInited) {
            zendeskInited = true
            initZendesk(this)
        }

        val data = (intent?.data?.pathSegments ?: emptyList()).map {
            it.split("=")
        }.map {
            if (it.size == 1) listOf(it[0], true) else it
        }.map {
            it[0] to it[1]
        }.toMap()

        if (data["list"] == true) {
            openListScreen()
            return
        }

        val id = data["id"]?.toString()
        val email = data["email"]?.toString() ?: Register.get(SupportUserInfo::class.java)?.email
        val name = data["name"]?.toString() ?: Register.get(SupportUserInfo::class.java)?.name

        if (id != null) {
            RequestActivity.builder()
                    .withRequestId(id)
                    .show(this)
            async {
                delay(2000)
                finish()
            }
        } else if (email != null) {
            openTicketScreen(email, name)
        } else {
            var newEmail: String? = null
            setContentView(R.layout.vbstepview)
            stepView.pages = listOf(
                    EnterEmailVB(ktx,
                            prefill = email,
                            accepted = {
                                newEmail = it
                                stepView.next()
                            }),
                    EnterNameVB(ktx,
                            prefill = name,
                            accepted = { newName ->
                                openTicketScreen(newEmail, newName)
                            }
                    )
            )
        }
    }

    private fun openTicketScreen(newEmail: String?, newName: String?) {
        val userInfo = get(SupportUserInfo::class.java)
        val name = newName ?: userInfo.getNameOrDefault()

        if (userInfo.hasChanged(newName, newEmail)) {
            val identity = AnonymousIdentity.Builder().withNameIdentifier(name)
            newEmail?.run { identity.withEmailIdentifier(this) }
            Zendesk.INSTANCE.setIdentity(identity.build())
            set(SupportUserInfo::class.java, userInfo.copy(name = newName, email = newEmail))
            v("updated support user info")
        }

        val dateFormat = SimpleDateFormat("MMMM", Locale.ENGLISH)
        val date = dateFormat.format(Date())

        val accountId = CustomField(360003464919L, get(CurrentAccount::class.java).id)
        val userAgent = CustomField(360007061479L, blokadaUserAgent(this))
        val customFields = listOf(accountId, userAgent)
        val file = File(this.filesDir, "/blokada.log")

        RequestActivity.builder()
                .withRequestSubject("Android issue from $name in $date")
                .withCustomFields(customFields)
                .withTags("android", BuildConfig.VERSION_NAME)
                .withFiles(file)
                .show(this)

        set(SupportUserInfo::class.java, get(SupportUserInfo::class.java).copy(hasTickets = true))

        async {
            delay(2000)
            finish()
        }
    }

    private fun openListScreen() {
        RequestListActivity.builder().show(this)

        async {
            delay(2000)
            finish()
        }
    }
}

class EnterEmailVB(
        private val ktx: AndroidKontext,
        private val prefill: String? = null,
        private val i18n: I18n = ktx.di().instance(),
        private val accepted: (String?) -> Unit = {}
): SlotVB() {

    private var input = prefill
    private var valid = prefill != null

    private fun validate(input: String) = when {
        validateEmail(input) -> null
        else -> i18n.getString(R.string.slot_enter_domain_error)
    }

    private fun validateEmail(it: String) = emailRegex.containsMatchIn(it.trim())

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(i18n.getString(R.string.menu_vpn_support_email.res()),
            description = i18n.getString(R.string.menu_vpn_support_email_desc.res()),
            action1 = Slot.Action(i18n.getString(R.string.slot_continue.res())) {
                if (valid) {
                    view.fold()
                    accepted(input)
                }
            }
        )
        view.onInput = { it ->
            input = it.trim()
            if (input?.isEmpty() != false) input = null
            val error = validate(it)
            valid = error == null
            error
        }

        input?.run { view.input = this }
        view.requestFocusOnEdit()
    }
}

val emailRegex = Regex("^[\\w\\.-]+@[\\w\\.-]+(\\.[\\w]+)+$")

class EnterNameVB(
        private val ktx: AndroidKontext,
        private val prefill: String?,
        private val i18n: I18n = ktx.di().instance(),
        private val accepted: (String?) -> Unit = {}
): SlotVB() {

    private var input = prefill
    private var valid = true

    private fun validate(input: String) = when {
        validateName(input) -> null
        input.trim().isEmpty() -> null
        else -> i18n.getString(R.string.slot_enter_domain_error)
    }

    private fun validateName(it: String) = it.length > 1

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(i18n.getString(R.string.menu_vpn_support_name.res()),
                description = i18n.getString(R.string.menu_vpn_support_name_desc.res()),
                action1 = Slot.Action(i18n.getString(R.string.slot_continue.res())) {
                    if (valid) {
                        view.fold()
                        accepted(input)
                    }
                }
        )
        view.onInput = { it ->
            input = it.trim()
            if (input?.isEmpty() != false) input = null
            val error = validate(it)
            valid = error == null
            error
        }

        input?.run { view.input = this }
        view.requestFocusOnEdit()
    }
}

