package core

import android.app.Activity
import com.github.salomonbrys.kodein.instance
import gs.property.I18n
import kotlinx.coroutines.experimental.async
import org.blokada.R
import tunnel.BLOCKA_CONFIG
import tunnel.checkAccountInfo


class RestoreAccountActivity : Activity() {

    private val stepView by lazy { findViewById<VBStepView>(R.id.view) }
    private val ktx = ktx("RestoreAccountActivity")

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)

        val nameVB = EnterAccountVB(ktx, accepted = {
            name = it
            restoreAccountId()
        })

        stepView.pages = listOf(
                nameVB
        )
    }

    override fun onBackPressed() {
//        if (!dashboardView.handleBackPressed()) super.onBackPressed()
        super.onBackPressed()
    }


    private var name = ""

    private fun restoreAccountId() = when {
        name.isBlank() -> Unit
        else -> {
            async {
                ktx.getMostRecent(BLOCKA_CONFIG)?.run {
                    checkAccountInfo(ktx, copy(restoredAccountId = name), showError = true)
                    finish()
                }
            }
            Unit
        }
    }

}

class EnterAccountVB(
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val accepted: (String) -> Unit = {}
) : SlotVB(), Stepable {

    private var input = ""
    private var inputValid = false
    private val inputRegex = Regex("^[A-z0-9]+$")

    private fun validate(input: String) = when {
        !input.matches(inputRegex) -> i18n.getString(R.string.slot_account_name_error)
        else -> null
    }

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.EDIT
        view.content = Slot.Content(i18n.getString(R.string.slot_account_name_title),
                description = i18n.getString(R.string.slot_account_name_desc),
                action1 = Slot.Action(i18n.getString(R.string.slot_account_name_restore)) {
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
