package blocka

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.github.salomonbrys.kodein.instance
import core.*
import gs.property.Device
import kotlinx.coroutines.experimental.async
import java.util.*

fun scheduleAccountChecks() = {
    scheduleDailyRecheck()
    scheduleAlarmRecheck()
}()

private fun scheduleDailyRecheck() = {
    val ctx = getActiveContext()!!
    val ktx = ctx.ktx("daily-account-recheck")
    val d: Device = ktx.di().instance()
    d.screenOn.doOnUiWhenChanged().then {
        if (d.screenOn()) async {
            val account = get(CurrentAccount::class.java)
            if (account.lastAccountCheck + 86400 * 1000 < System.currentTimeMillis()) {
                v("daily account recheck")
                entrypoint.onAccountChanged()
            }
        }
    }
}()

class RenewLicenseReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, p1: Intent) {
        async {
            v("recheck account / lease task executing")
            entrypoint.onAccountChanged()
        }
    }
}

private fun scheduleAlarmRecheck() {
    val ctx = getActiveContext()!!
    val alarm: AlarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    val operation = Intent(ctx, RenewLicenseReceiver::class.java).let { intent ->
        PendingIntent.getBroadcast(ctx, 0, intent, 0)
    }

    val account = get(CurrentAccount::class.java)
    val lease = get(CurrentLease::class.java)
    val accountTime = account.activeUntil
    val leaseTime = lease.leaseActiveUntil
    val sooner = if (accountTime.before(leaseTime)) accountTime else leaseTime
    if (sooner.before(Date())) {
        entrypoint.onAccountChanged()
    } else {
        alarm.set(AlarmManager.RTC, sooner.time, operation)
        v("scheduled account / lease recheck for $sooner")
    }

}

private fun Date.minus(minutes: Int) = Date(this.time - minutes * 60 * 1000)
