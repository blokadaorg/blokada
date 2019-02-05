package core

import android.app.Application
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import buildtype.newBuildTypeModule
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.KodeinAware
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.lazy
import flavor.newFlavorModule
import gs.environment.inject
import gs.environment.newGscoreModule
import gs.property.Device
import gs.property.IWhen
import gs.property.newDeviceModule
import gs.property.newUserModule
import io.paperdb.Paper
import org.acra.ACRA
import org.acra.ReportField
import org.acra.config.CoreConfigurationBuilder
import org.acra.config.DialogConfigurationBuilder
import org.acra.config.HttpSenderConfigurationBuilder
import org.acra.config.LimiterConfigurationBuilder
import org.acra.data.StringFormat
import org.acra.sender.HttpSender
import org.blokada.BuildConfig
import org.blokada.R


/**
 * Main.kt contains all entry points of the app.
 */

private fun startThroughJobScheduler(
        ctx: Context,
        scheduler: JobScheduler = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
) {
    val serviceComponent = ComponentName(ctx, BootJobService::class.java)
    val builder = JobInfo.Builder(0, serviceComponent)
    builder.setOverrideDeadline(3 * 1000L)
    scheduler.schedule(builder.build())
}

class MainApplication: Application(), KodeinAware {

    override val kodein by Kodein.lazy {
        import(newGscoreModule(this@MainApplication))
        import(newDeviceModule(this@MainApplication))
        import(newUserModule(this@MainApplication))
        import(newTunnelModule(this@MainApplication))
        import(newFiltersModule(this@MainApplication))
        import(newDnsModule(this@MainApplication))
        import(newWelcomeModule(this@MainApplication))
        import(newPagesModule(this@MainApplication))
        import(newUpdateModule(this@MainApplication))
        import(newKeepAliveModule(this@MainApplication))
        import(newAppModule(this@MainApplication), allowOverride = true)
        import(newFlavorModule(this@MainApplication), allowOverride = true)
        import(newBuildTypeModule(this@MainApplication), allowOverride = true)
    }

    override fun onCreate() {
        super.onCreate()
        val ktx = "boot".ktx()
        repeat(10) { ktx.v("BLOKADA", "*".repeat(it * 2)) }
        setRestartAppOnCrash()
        Paper.init(this)
    }

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        val builder = CoreConfigurationBuilder(this)
        builder.setBuildConfigClass(BuildConfig::class.java).setReportFormat(StringFormat.JSON)
        builder.setLogcatArguments("-t", "600", "-v", "threadtime")
        builder.setReportContent(
                ReportField.INSTALLATION_ID,
                ReportField.USER_COMMENT,
                ReportField.BUILD_CONFIG,
                ReportField.CUSTOM_DATA,
                ReportField.SHARED_PREFERENCES,
                ReportField.STACK_TRACE,
                ReportField.THREAD_DETAILS,
                ReportField.LOGCAT,
                ReportField.PACKAGE_NAME,
                ReportField.ANDROID_VERSION,
                ReportField.APP_VERSION_NAME,
                ReportField.TOTAL_MEM_SIZE,
                ReportField.AVAILABLE_MEM_SIZE,
                ReportField.SETTINGS_SYSTEM,
                ReportField.SETTINGS_SECURE
        )
        builder.setAdditionalSharedPreferences("default", "basic")

        val c = builder.getPluginConfigurationBuilder(HttpSenderConfigurationBuilder::class.java)
        c.setEnabled(true)
        c.setHttpMethod(HttpSender.Method.POST)
        c.setUri(getString(R.string.acra_uri))
        c.setBasicAuthLogin(getString(R.string.acra_login))
        c.setBasicAuthPassword(getString(R.string.acra_password))
        c.setDropReportsOnTimeout(true)

        if (ProductType.isPublic()) {
            val limiter = builder.getPluginConfigurationBuilder(LimiterConfigurationBuilder::class.java)
            limiter.setEnabled(true)
            limiter.setOverallLimit(7)
            limiter.setStacktraceLimit(2)
            limiter.setExceptionClassLimit(3)
            limiter.setResIgnoredCrashToast(R.string.main_report_limit)
        }

        val dialog = builder.getPluginConfigurationBuilder(DialogConfigurationBuilder::class.java)
        dialog.setEnabled(true)
        dialog.setResTitle(R.string.main_report_title)
        dialog.setResText(R.string.main_report_text)
        dialog.setResCommentPrompt(R.string.main_report_comment)
        dialog.setResTheme(R.style.GsTheme_Dialog)
        dialog.setResIcon(R.drawable.ic_blokada)

        val d: Device = kodein.instance()
        if (d.reports()) ACRA.init(this, builder)
    }

    private fun setRestartAppOnCrash() {
        Thread.setDefaultUncaughtExceptionHandler { _, ex ->
            try {
                ACRA.getErrorReporter().handleException(ex)
                "fatal".ktx().e(ex)
            } catch (e: Exception) {}
            startThroughJobScheduler(this)
            System.exit(2)
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        "boot".ktx().v("received boot event")
        startThroughJobScheduler(ctx)
    }
}

class BootJobService : JobService() {

    private val d by lazy { inject().instance<Device>() }
    private val t by lazy { inject().instance<Tunnel>() }
    private val ktx by lazy { "boot:service".ktx() }

    override fun onStartJob(params: JobParameters?): Boolean {
        ktx.v("boot job start")
        d.connected.refresh()
        d.onWifi.refresh()
        return scheduleJobFinish(params)
    }

    private fun scheduleJobFinish(params: JobParameters?): Boolean {
        return try {
            when {
                t.active() -> {
                    ktx.v("boot job finnish immediately, already active")
                    false
                }
                !t.enabled() -> {
                    ktx.v("boot job finnish immediately, not enabled")
                    false
                }
                listener != null -> {
                    ktx.v("boot job finnish immediately, service waiting")
                    false
                }
                else -> {
                    ktx.v("boot job scheduling to stop when tunnel active")
                    listener = t.active.doOnUiWhenChanged().then {
                        t.active.cancel(listener)
                        listener = null
                        jobFinished(params, false)
                    }
                    true
                }
            }
        } catch (e: Exception) {
            ktx.e("boot job fail", e)
            false
        }
    }

    private var listener: IWhen? = null

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }

}

