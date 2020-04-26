package ui

import android.os.Bundle
import com.twofortyfouram.locale.sdk.client.ui.activity.AbstractPluginActivity
import core.*
import gs.presentation.ListViewBinder
import org.blokada.R

class TaskerActivity : AbstractPluginActivity() {

    private val stepView by lazy { findViewById<VBStepView>(R.id.view) }

    private val switch: TaskerSwitchVB = TaskerSwitchVB(true,
        label = "Blokada".res(),
        icon = R.drawable.ic_power.res(),
        onSelected = { updateSwitches(0) })

    private val switchBlockaVpn: TaskerSwitchVB = TaskerSwitchVB(true,
        label = "Blokada Tunnel".res(),
        icon = R.drawable.ic_verified.res(),
        onSelected = { updateSwitches(1) })

    private val switchDns: TaskerSwitchVB = TaskerSwitchVB(true,
        label = "Blokada DNS".res(),
        icon = R.drawable.ic_server.res(),
        onSelected = { updateSwitches(2) })

    private val list = object : ListViewBinder() {
        override fun attach(view: VBListView) {
            view.orderFromTop()
            view.set(
                listOf(
                    LabelVB(ktx("label"), label = R.string.tasker_switch_label.res()),
                    switch,
                    switchDns,
                    switchBlockaVpn
                )
            )
        }
    }

    private fun updateSwitches(pos: Int) {
        when (pos) {
            0 -> {
                switch.active()
                switchBlockaVpn.inactive()
                switchDns.inactive()
            }
            1 -> {
                switch.inactive()
                switchBlockaVpn.active()
                switchDns.inactive()
            }
            2 -> {
                switch.inactive()
                switchBlockaVpn.inactive()
                switchDns.active()
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)
        stepView.pages = listOf(list)
    }

    override fun onPostCreateWithPreviousResult(previousBundle: Bundle, previousBlurp: String) {
        when {
            previousBundle.containsKey(EVENT_KEY_SWITCH) -> {
                updateSwitches(0)
                switch.value = previousBundle.getBoolean(EVENT_KEY_SWITCH)
            }
            previousBundle.containsKey(EVENT_KEY_SWITCH_BLOCKA_VPN) -> {
                updateSwitches(1)
                switchBlockaVpn.value = previousBundle.getBoolean(EVENT_KEY_SWITCH_BLOCKA_VPN)
            }
            previousBundle.containsKey(EVENT_KEY_SWITCH_DNS) -> {
                updateSwitches(2)
                switchDns.value = previousBundle.getBoolean(EVENT_KEY_SWITCH_DNS)
            }
        }
    }

    override fun getResultBundle() = Bundle().apply {
        when {
            switch.active -> putBoolean(EVENT_KEY_SWITCH, switch.value)
            switchBlockaVpn.active -> putBoolean(EVENT_KEY_SWITCH_BLOCKA_VPN, switchBlockaVpn.value)
            switchDns.active -> putBoolean(EVENT_KEY_SWITCH_DNS, switchDns.value)
        }
    }

    override fun isBundleValid(bundle: Bundle) = bundle.containsKey(EVENT_KEY_SWITCH)
            || bundle.containsKey(EVENT_KEY_SWITCH_DNS)
            || bundle.containsKey(EVENT_KEY_SWITCH_BLOCKA_VPN)

    override fun getResultBlurb(bundle: Bundle): String {
        val (what, isTrue) = when {
            bundle.containsKey(EVENT_KEY_SWITCH_BLOCKA_VPN) -> {
                "Blokada Tunnel" to bundle.getBoolean(EVENT_KEY_SWITCH_BLOCKA_VPN)
            }
            bundle.containsKey(EVENT_KEY_SWITCH_DNS) -> {
                "DNS" to bundle.getBoolean(EVENT_KEY_SWITCH_DNS)
            }
            else -> {
                "Blokada" to bundle.getBoolean(EVENT_KEY_SWITCH)
            }
        }

        val doWhat = if (isTrue) getString(R.string.slot_action_activate)
        else getString(R.string.slot_action_deactivate)

        // TODO: super lazy way...
        return "%s - %s".format(what, doWhat)
    }

}

class TaskerSwitchVB(
    internal var value: Boolean,
    private val label: Resource,
    private val icon: Resource,
    var active: Boolean = false,
    private val onSelected: () -> Any
) : BitVB() {
    override fun attach(view: BitView) {
        view.alternative(true)
        view.icon(icon)
        view.label(label)
        view.switch(value)
        view.onSwitch { value = it }
        view.onTap { onSelected() }
        if (active) active() else inactive()
    }

    fun active() {
        active = true
        view?.run {
            inactive(false)
            icon(icon, Resource.ofResId(R.color.switch_on))
            switch(value)
        }
    }

    fun inactive() {
        active = false
        view?.run {
            inactive(true)
            icon(icon)
            switch(null)
        }
    }
}
