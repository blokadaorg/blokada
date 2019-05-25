package adblocker

import android.Manifest
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.IBinder
import android.support.v4.app.ActivityCompat
import android.support.v4.content.ContextCompat
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.ScrollView
import android.widget.Toast
import com.github.michaelbull.result.mapBoth
import core.*
import gs.presentation.SwitchCompatView
import org.blokada.R
import tunnel.Events
import java.io.File
import java.io.FileOutputStream
import java.io.PrintWriter
import java.util.*


class RequestLogWriter {

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

class LoggerDash(
        val ctx: Context
) : Dash(
        "logger_settings",
        icon = R.drawable.ic_tune,
        text = ctx.getString(R.string.logger_dash_title),
        hasView = true
) {
    private val config: LoggerConfigPersistence = LoggerConfigPersistence()

    override fun createView(parent: Any): Any? {
        return createConfigView(parent as ViewGroup)
    }

    private var configView: LoggerConfigView? = null

    private fun createConfigView(parent: ViewGroup): LoggerConfigView {
        val ctx = parent.context
        configView = LayoutInflater.from(ctx).inflate(R.layout.view_logger_config, parent, false) as LoggerConfigView

        configView?.onNewConfig = {
            val serviceIntent = Intent(ctx.applicationContext,
                    RequestLogger::class.java)
            val newConfigArray = BooleanArray(3)
            newConfigArray[0] = it.active
            newConfigArray[1] = it.logAllowed
            newConfigArray[2] = it.logDenied
            serviceIntent.putExtra("config", newConfigArray)
            ctx.startService(serviceIntent)
            config.save(it)
        }
        configView?.config = config.load(ctx.ktx())
        return configView!!
    }
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
        val active: Boolean = false,
        val logAllowed: Boolean = false,
        val logDenied: Boolean = false
)

class LoggerConfigView(
        val ctx: Context,
        attributeSet: AttributeSet
) : ScrollView(ctx, attributeSet) {

    var config = LoggerConfig()
        set(value) {
            field = value
            activeSwitch.isChecked = value.active
            allowedCheck.isChecked = value.logAllowed
            deniedCheck.isChecked = value.logDenied
            onNewConfig(value)
        }

    var onNewConfig = { config: LoggerConfig -> }

    private val activeSwitch by lazy { findViewById<SwitchCompatView>(R.id.switch_logger_active) }
    private val allowedCheck by lazy { findViewById<CheckBox>(R.id.check_logger_allowed) }
    private val deniedCheck by lazy { findViewById<CheckBox>(R.id.check_logger_denied) }

    override fun onFinishInflate() {
        super.onFinishInflate()
        activeSwitch.setOnCheckedChangeListener { buttonView, isChecked ->
            if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                Toast.makeText(ctx, ctx.resources.getString(R.string.logger_permission), Toast.LENGTH_SHORT).show()
                buttonView.isChecked = false
            } else {
                config = config.copy(active = isChecked)
            }
        }
        allowedCheck.setOnCheckedChangeListener { _, isChecked ->
            config = config.copy(logAllowed = isChecked)
        }
        deniedCheck.setOnCheckedChangeListener { _, isChecked ->
            config = config.copy(logDenied = isChecked)
        }
    }
}


class RequestLogger : Service() {
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private var logger: RequestLogWriter? = null
    private var onAllowed = { host: String -> log(host, false) }
    private var onBlocked = { host: String -> log(host, true) }
    var config = LoggerConfig()
        set(value) {
            if (field != value) {
                this.ktx().cancel(Events.ALLOWED, onAllowed)
                this.ktx().cancel(Events.BLOCKED, onBlocked)
                if (value.active) {
                    logger = RequestLogWriter()
                    if (value.logAllowed) {
                        this.ktx().on(Events.ALLOWED, onAllowed)
                    }
                    if (value.logDenied) {
                        this.ktx().on(Events.BLOCKED, onBlocked)
                    }
                } else {
                    stopSelf()
                }
                field = value
            }
        }

    fun log(host: String, blocked: Boolean) {
        logger?.writer(if (blocked) {
            'b'
        } else {
            'a'
        } + "," + host)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val newConfig: BooleanArray? = intent.getBooleanArrayExtra("config")

            if (newConfig != null) {
                if (newConfig.size == 3) {
                    config = LoggerConfig(active = newConfig[0], logAllowed = newConfig[1], logDenied = newConfig[2])
                }
            } else {
                if (intent.getBooleanExtra("load_on_start", false)) {
                    val persistenceConfig = LoggerConfigPersistence()
                    config = persistenceConfig.load(this.ktx())
                }
            }
        }
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onDestroy() {
        this.ktx().cancel(Events.ALLOWED, onAllowed)
        this.ktx().cancel(Events.BLOCKED, onBlocked)
        super.onDestroy()
    }
}
