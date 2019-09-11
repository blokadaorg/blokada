package blocka

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import core.AndroidKontext
import core.v
import kotlinx.coroutines.experimental.async
import tunnel.BlockaConfig

fun scheduleAccountChecks() = {
    scheduleDailyRecheck()
    //scheduleAlarmRecheck()
}()

private fun scheduleDailyRecheck() = {
//    val d: Device = ktx.di().instance()
//    d.screenOn.doOnUiWhenChanged().then {
//        if (d.screenOn()) async {
//            ktx.getMostRecent(BLOCKA_CONFIG)?.run {
//                if (!DateUtils.isToday(lastDaily)) {
//                    ktx.v("daily check account")
//                    checkAccountInfo(ktx, copy(lastDaily = System.currentTimeMillis()))
//                }
//            }
//        }
//    }
}()

class RenewLicenseReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, p1: Intent) {
        async {
            v("recheck account / lease task executing")
//            val config = ktx.getMostRecent(BLOCKA_CONFIG)!!
//            checkAccountInfo(ktx, config)
            // TODO
        }
    }
}

private fun scheduleAlarmRecheck(ktx: AndroidKontext, config: BlockaConfig) {
//    val alarm: AlarmManager = ktx.ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
//
//    val operation = Intent(ktx.ctx, RenewLicenseReceiver::class.java).let { intent ->
//        PendingIntent.getBroadcast(ktx.ctx, 0, intent, 0)
//    }
//
//    val accountTime = config.getAccountExpiration()
//    val leaseTime = config.getLeaseExpiration()
//    val sooner = if (accountTime.before(leaseTime)) accountTime else leaseTime
//    if (sooner.before(Date())) {
//        ktx.emit(BLOCKA_CONFIG, config.copy(enabled = false))
//        async {
//            // Wait until tunnel is off and recheck
//            delay(3000)
//            checkAccountInfo(ktx, config)
//        }
//    } else {
//        alarm.set(AlarmManager.RTC, sooner.time, operation)
//        ktx.v("scheduled account / lease recheck for $sooner")
//    }
}
