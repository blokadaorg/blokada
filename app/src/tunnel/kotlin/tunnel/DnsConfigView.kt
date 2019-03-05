package tunnel

import android.content.Context
import android.util.AttributeSet
import android.widget.ScrollView
import com.github.salomonbrys.kodein.instance
import core.Dns
import gs.environment.inject
import gs.presentation.SwitchCompatView
import gs.property.Device
import org.blokada.R


class DnsConfigView(
        ctx: Context,
        attributeSet: AttributeSet
) : ScrollView(ctx, attributeSet) {

    val reports by lazy { ctx.inject().instance<Device>().reports }
    val fallback by lazy { ctx.inject().instance<Dns>().fallback }

    private val reportsSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_reports) }
    private val fallbackSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_fallback) }

    override fun onFinishInflate() {
        super.onFinishInflate()
        reportsSwitch.setOnCheckedChangeListener { _, isChecked ->
            reports %= isChecked }
        fallbackSwitch.setOnCheckedChangeListener { _, isChecked ->
            fallback %= isChecked }

        syncView()

        reports.doOnUiWhenSet().then {
            reportsSwitch.isChecked = reports()
        }

        fallback.doOnUiWhenSet().then {
            fallbackSwitch.isChecked = fallback()
        }
    }

    private fun syncView() {
        reportsSwitch.isChecked = reports()
        fallbackSwitch.isChecked = fallback()
    }

}
