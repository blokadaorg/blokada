package adblocker

import android.app.Activity
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import com.github.michaelbull.result.mapBoth
import com.github.salomonbrys.kodein.instance
import core.*
import gs.environment.ComponentProvider
import gs.property.I18n
import org.blokada.R
import tunnel.Request
import tunnel.TunnelEvents
import java.io.File
import java.io.FileOutputStream
import java.io.PrintWriter
import java.util.*


class CsvLogWriter {

    private var file: PrintWriter? = try {
        val path = File(getExternalPath(), "requests.csv")
        val exists = path.exists()
        val writer = PrintWriter(FileOutputStream(path, true), true)
        if (!exists) {
            writer.println("timestamp,type,host")
        }
        writer
    } catch (ex: Exception) {
        null
    }

    @Synchronized
    internal fun writer(line: String) {
        Result.of { file!!.println(time() + ',' + line) }
    }

    private fun time() = Date().time.toString(10)
}

class LoggerConfigPersistence {
    val load = { ktx: Kontext ->
        Result.of { core.Persistence.paper().read<LoggerConfig>("logger:config", LoggerConfig()) }
            .mapBoth(
                success = { it },
                failure = { ex ->
                    ktx.w("failed loading LoggerConfig, reverting to defaults", ex)
                    LoggerConfig()
                }
            )
    }

    val save = { config: LoggerConfig ->
        Result.of { core.Persistence.paper().write("logger:config", config) }
    }
}

data class LoggerConfig(
    val active: Boolean = true,
    val logAllowed: Boolean = false,
    val logDenied: Boolean = false
)

class RequestLogger : Service() {
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private var logger: CsvLogWriter? = null
    private var onAllowed = { r: Request -> if (!r.blocked) log(r.domain, false) }
    private var onBlocked = { r: Request -> if (r.blocked) log(r.domain, true) }
    private var onRequest = { r: Request -> emit(TunnelEvents.REQUEST_SAVED, r); Unit }
    var config = LoggerConfig(active = false)
        set(value) {

            if (field != value) {
                this.ktx().cancel(TunnelEvents.REQUEST_SAVED, onAllowed)
                this.ktx().cancel(TunnelEvents.REQUEST_SAVED, onBlocked)
                this.ktx().cancel(TunnelEvents.REQUEST, onRequest)
                if (value.active) {
                    logger = CsvLogWriter()
                    if (value.logAllowed) {
                        this.ktx().on(TunnelEvents.REQUEST_SAVED, onAllowed)
                    }
                    if (value.logDenied) {
                        this.ktx().on(TunnelEvents.REQUEST_SAVED, onBlocked)
                    }
                    this.ktx().on(TunnelEvents.REQUEST, onRequest)
                } else {
                    stopSelf()
                }
                field = value
            }
        }

    fun log(host: String, blocked: Boolean) {
        logger?.writer(
            if (blocked) {
                'b'
            } else {
                'a'
            } + "," + host
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        this.ktx().v("logger service started")
        if (intent != null) {
            val newConfig: BooleanArray? = intent.getBooleanArrayExtra("config")

            if (newConfig != null) {
                if (newConfig.size == 3) {
                    config = LoggerConfig(
                        active = newConfig[0],
                        logAllowed = newConfig[1],
                        logDenied = newConfig[2]
                    )
                }
            } else {
                if (intent.getBooleanExtra("load_on_start", false)) {
                    val persistenceConfig = LoggerConfigPersistence()
                    config = persistenceConfig.load(this.ktx())
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        this.ktx().cancel(TunnelEvents.REQUEST_SAVED, onAllowed)
        this.ktx().cancel(TunnelEvents.REQUEST_SAVED, onBlocked)
        this.ktx().cancel(TunnelEvents.REQUEST, onRequest)
        super.onDestroy()
    }
}

class LoggerVB(
    private val ktx: AndroidKontext,
    private val i18n: I18n = ktx.di().instance(),
    private val activity: ComponentProvider<Activity> = ktx.di().instance(),
    onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    val persistence = LoggerConfigPersistence()

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.enableAlternativeBackground()
        val config = persistence.load(ktx)
        view.apply {
            content = Slot.Content(
                label = i18n.getString(R.string.logger_slot_title),
                description = i18n.getString(R.string.logger_slot_desc),
                values = listOf(
                    i18n.getString(R.string.logger_slot_mode_off),
                    i18n.getString(R.string.logger_slot_mode_internal),
                    i18n.getString(R.string.logger_slot_mode_denied),
                    i18n.getString(R.string.logger_slot_mode_allowed),
                    i18n.getString(R.string.logger_slot_mode_all)
                ),
                selected = configToMode(config)
            )
        }
        view.onSelect = {
            val newConfig = modeToConfig(it)
            if (newConfig.logAllowed || newConfig.logDenied) {
                askForExternalStoragePermissionsIfNeeded(activity)
            }
            persistence.save(newConfig)
            sendConfigToService(ktx.ctx, newConfig)
        }
    }

    private fun configToMode(config: LoggerConfig) = i18n.getString(
        when {
            !config.active -> R.string.logger_slot_mode_off
            config.logAllowed && config.logDenied -> R.string.logger_slot_mode_all
            config.logDenied -> R.string.logger_slot_mode_denied
            config.logAllowed -> R.string.logger_slot_mode_allowed
            else -> R.string.logger_slot_mode_internal
        }
    )

    private fun modeToConfig(mode: String) = when (mode) {
        i18n.getString(R.string.logger_slot_mode_off) -> LoggerConfig(active = false)
        i18n.getString(R.string.logger_slot_mode_allowed) -> LoggerConfig(
            active = true,
            logAllowed = true
        )
        i18n.getString(R.string.logger_slot_mode_denied) -> LoggerConfig(
            active = true,
            logDenied = true
        )
        i18n.getString(R.string.logger_slot_mode_all) -> LoggerConfig(
            active = true,
            logAllowed = true,
            logDenied = true
        )
        else -> LoggerConfig()
    }

    private fun sendConfigToService(ctx: Context, config: LoggerConfig) {
        val serviceIntent = Intent(ctx.applicationContext, RequestLogger::class.java)
        val newConfigArray = BooleanArray(3)
        newConfigArray[0] = config.active
        newConfigArray[1] = config.logAllowed
        newConfigArray[2] = config.logDenied
        serviceIntent.putExtra("config", newConfigArray)
        ctx.startService(serviceIntent)
    }

    private fun askForExternalStoragePermissionsIfNeeded(activity: ComponentProvider<Activity>) {
        if (!checkStoragePermissions(ktx)) {
            activity.get()?.apply {
                askStoragePermission(ktx, this)
            }
        }
    }
}
