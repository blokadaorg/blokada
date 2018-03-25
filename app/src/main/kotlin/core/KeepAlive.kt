package core

import android.app.Service
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Binder
import android.os.IBinder
import com.github.salomonbrys.kodein.instance
import gs.environment.ComponentProvider
import gs.environment.Journal
import gs.environment.inject
import notification.createNotificationKeepAlive
import org.blokada.R

class KeepAliveAgent {
    private val serviceConnection = object: ServiceConnection {
        @Synchronized override fun onServiceConnected(name: ComponentName, binder: IBinder) {}
        @Synchronized override fun onServiceDisconnected(name: ComponentName?) {}
    }

    fun bind(ctx: Context) {
        scheduleJob(ctx)
        val intent = Intent(ctx, KeepAliveService::class.java)
        intent.action = KeepAliveService.BINDER_ACTION
        ctx.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    fun unbind(ctx: Context) {
        try { unscheduleJob(ctx) } catch (e: Exception) {}
        try { ctx.unbindService(serviceConnection) } catch (e: Exception) {}
    }

    fun scheduleJob(ctx: Context) {
        val serviceComponent = ComponentName(ctx, BootJobService::class.java)
        val builder = JobInfo.Builder(1, serviceComponent)
        builder.setPeriodic(60 * 1000L)
        val jobScheduler = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        jobScheduler.schedule(builder.build())
    }

    fun unscheduleJob(ctx: Context) {
        val jobScheduler = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        jobScheduler.cancel(1)
    }
}

class KeepAliveService : Service() {

    companion object Statics {
        val BINDER_ACTION = "KeepAliveService"
    }

    class KeepAliveBinder : Binder()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val j: Journal = inject().instance()
        j.log("KeepAliveService start command")
        return Service.START_STICKY;
    }

    private var binder: KeepAliveBinder? = null
    override fun onBind(intent: Intent?): IBinder? {
        if (BINDER_ACTION.equals(intent?.action)) {
            binder = KeepAliveBinder()

            val s: State = inject().instance()
            val count = s.tunnelDropCount()
            val last = s.tunnelRecentDropped().lastOrNull() ?: getString(R.string.notification_keepalive_none)
            val n = createNotificationKeepAlive(this, count, last)
            startForeground(3, n)

            val provider: ComponentProvider<BootJobService> = inject().instance()
            val service = provider.get()
            if (service != null) {
                try { service.jobFinished(service.params, false) } catch (e: Exception) {}
                provider.unset()
            }

            return binder
        }
        return null
    }

    override fun onUnbind(intent: Intent?): Boolean {
        binder = null
        stopForeground(true)
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        // This is probably pointless
        if (binder != null) sendBroadcast(Intent("org.blokada.keepAlive"))
    }

}

class BootJobService : JobService() {

    var params: JobParameters? = null

    override fun onStartJob(params: JobParameters?): Boolean {
        // Simply creating a context will init the app.
        // If KeepAlive is enabled, it'll keep the app alive from now on.
        val s: State = inject().instance()
        val j: Journal = inject().instance()
        j.log("BootJobService onStartJob")
        s.connection.refresh()
        if (s.keepAlive()) {
            j.log("BootJobService: KeepAlive is on")
            val provider: ComponentProvider<BootJobService> = inject().instance()
            provider.set(this)
            this.params = params
            return true
        } else return false
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }

}
