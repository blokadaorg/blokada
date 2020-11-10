package core

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.bind
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.singleton
import gs.property.I18n
import gs.property.getBrandedString
import org.blokada.R


class Battery(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.di().instance(),
        private val powerManager: PowerManager = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
) {
    fun isWhitelisted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            powerManager.isIgnoringBatteryOptimizations(ctx.packageName)
        } else {
            true
        }
    }

    fun openWhitelistingScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent().apply {
                action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            ctx.startActivity(intent)
        }
    }
}


fun newBatteryModule(ctx: Context) = Kodein.Module {
    bind<Battery>() with singleton { Battery(ctx.ktx("battery")) }
}

class BatteryVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        private val battery: Battery = ktx.di().instance(),
        private val onRemove: () -> Unit = {},
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getBrandedString(R.string.battery_title),
                description = i18n.getBrandedString(R.string.battery_description),
                icon = ctx.getDrawable(R.drawable.ic_battery),
                action1 = Slot.Action(i18n.getString(R.string.battery_action), {
                    battery.openWhitelistingScreen()
                    onRemove()
                })
        )
    }

}
