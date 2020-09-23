package adblocker

import android.app.Activity
import com.github.salomonbrys.kodein.instance
import core.*
import core.Register.set
import gs.environment.ComponentProvider
import gs.property.I18n
import org.blokada.R
import tunnel.ExtendedRequest
import tunnel.LogConfig
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
    private fun writer(line: String) {
        Result.of { file!!.println(time() + ',' + line) }
    }

    fun log(requests: List<ExtendedRequest>) { //TODO show all states of RequestState instead of a/b
        val config = get(LogConfig::class.java)
        requests.filter { request -> request.blocked && config.csvLogDenied || !request.blocked && config.csvLogAllowed}.forEach { request ->
            writer(if (request.blocked) {
                'b'
            } else {
                'a'
            } + "," + request.domain)
        }
    }

    private fun time() = Date().time.toString(10)
}

data class OldLoggerConfig( //TODO legacy loader?
        val active: Boolean = true,
        val logAllowed: Boolean = false,
        val logDenied: Boolean = false
)

class LoggerVB (
        private val ktx: AndroidKontext,
        private val i18n: I18n = ktx.di().instance(),
        private val activity: ComponentProvider<Activity> = ktx.di().instance(),
        onTap: (SlotView) -> Unit
): SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.type = Slot.Type.INFO
        view.enableAlternativeBackground()
        val config = get(LogConfig::class.java)
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
            if (newConfig.csvLogAllowed || newConfig.csvLogDenied) {
                askForExternalStoragePermissionsIfNeeded(activity)
            }
            set(LogConfig::class.java, newConfig)
        }
    }

    private fun configToMode(config: LogConfig) = i18n.getString(
            when {
                !config.logActive -> R.string.logger_slot_mode_off
                config.csvLogAllowed && config.csvLogDenied -> R.string.logger_slot_mode_all
                config.csvLogDenied -> R.string.logger_slot_mode_denied
                config.csvLogAllowed -> R.string.logger_slot_mode_allowed
                else -> R.string.logger_slot_mode_internal
    })

    private fun modeToConfig(mode: String) = when (mode) {
        i18n.getString(R.string.logger_slot_mode_off) -> LogConfig(logActive = false)
        i18n.getString(R.string.logger_slot_mode_allowed) -> LogConfig(logActive = true, csvLogAllowed = true)
        i18n.getString(R.string.logger_slot_mode_denied) -> LogConfig(logActive = true, csvLogDenied = true)
        i18n.getString(R.string.logger_slot_mode_all) -> LogConfig(logActive = true, csvLogAllowed = true, csvLogDenied = true)
        else -> LogConfig()
    }

    private fun askForExternalStoragePermissionsIfNeeded(activity: ComponentProvider<Activity>) {
        if (!checkStoragePermissions(ktx)) {
            activity.get()?.apply {
                askStoragePermission(ktx, this)
            }
        }
    }
}
