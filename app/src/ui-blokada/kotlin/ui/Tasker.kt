package ui

import android.os.Bundle
import com.twofortyfouram.locale.sdk.client.ui.activity.AbstractPluginActivity
import core.*
import gs.presentation.ListViewBinder
import org.blokada.R

class TaskerActivity : AbstractPluginActivity() {

    private val stepView by lazy { findViewById<VBStepView>(R.id.view) }
    private val switch = TaskerSwitchVB(true)

    private val list = object : ListViewBinder() {
        override fun attach(view: VBListView) {
            view.orderFromTop()
            view.set(listOf(
                    LabelVB(ktx("label"), label = R.string.tasker_switch_label.res()),
                    switch
            ))
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)
        stepView.pages = listOf(list)
    }

    override fun onPostCreateWithPreviousResult(previousBundle: Bundle, previousBlurp: String) {
        switch.value = previousBundle.isTrue()
    }

    override fun getResultBundle() = Bundle().apply {
        putBoolean(EVENT_KEY_SWITCH, switch.value)
    }

    override fun isBundleValid(bundle: Bundle) = bundle.containsKey(EVENT_KEY_SWITCH)

    override fun getResultBlurb(bundle: Bundle): String {
        return if (bundle.isTrue()) getString(R.string.slot_action_activate)
        else getString(R.string.slot_action_deactivate)
    }

    private fun Bundle.isTrue() = this.getBoolean(EVENT_KEY_SWITCH)
}

class TaskerSwitchVB(
    internal var value: Boolean
) : BitVB() {
    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(R.drawable.ic_power.res())
        view.label(R.string.slot_action_activate.res())
        view.switch(value)
        view.onSwitch { value = it }
    }

}
