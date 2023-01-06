/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import android.app.Activity
import android.app.AlertDialog
import android.app.job.JobParameters
import android.app.job.JobService
import android.content.Intent
import android.graphics.Typeface
import android.util.Log
import android.widget.TextView
import androidx.core.app.ShareCompat
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import utils.Logger
import java.io.BufferedReader
import java.io.File
import java.io.IOException
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets
import java.text.DateFormat
import java.text.ParseException
import java.text.SimpleDateFormat
import java.time.Instant
import java.util.*
import java.util.regex.Matcher
import java.util.regex.Pattern

object LogService {

    private val context = ContextService
    private val file = FileService
    private val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZZZZZ", Locale.ENGLISH);

    init {
        GlobalScope.launch {
            Log.println(Log.VERBOSE, "Logger", "Starting logcat streaming")
            streamingLog()
        }
    }

    fun onShareLog(name: String, run: PrintsDebugInfo) {
        Logger.v("Log", "Adding onShareLog callback for $name")
        onShareLogCallbacks += name to run
    }

    private var onShareLogCallbacks = emptyMap<String, PrintsDebugInfo>()

    private val handle by lazy {
        val handle = file.commonDir().file("blokada.log.txt")
        Log.println(Log.VERBOSE, "Logger", "Logger will log to file: $handle")
        handle
    }

    private suspend fun streamingLog() = withContext(Dispatchers.IO) {
        val builder = ProcessBuilder().command("logcat", "-b", "all", "-v", "threadtime", "*:V")
        builder.environment()["LC_ALL"] = "C"
        var process: Process? = null
        try {
            process = try {
                builder.start()
            } catch (e: IOException) {
                Log.println(Log.ERROR, "Logger", "Could not stream logcat")
                Log.println(Log.ERROR, "Logger", Log.getStackTraceString(e))
                return@withContext
            }
            val stdout = BufferedReader(InputStreamReader(process!!.inputStream, StandardCharsets.UTF_8))
            var haveScrolled = false
            val start = System.nanoTime()
            var startPeriod = start
            while (true) {
                val line = stdout.readLine() ?: break
                parseLine(line)?.let { p ->
                    saveToFile(p.level, p.tag, p.msg, p.time)
                }
            }
        } finally {
            process?.destroy()
        }
    }

    private fun parseTime(timeStr: String): Date? {
        val formatter: DateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)
        return try {
            formatter.parse("$year-$timeStr")
        } catch (e: ParseException) {
            null
        }
    }

    private val year by lazy {
        val yearFormatter: DateFormat = SimpleDateFormat("yyyy", Locale.US)
        yearFormatter.format(Date())
    }

    private fun parseLine(line: String): LogLine? {
        val m: Matcher = THREADTIME_LINE.matcher(line)
        return if (m.matches()) {
            LogLine(m.group(2)!!.toInt(), m.group(3)!!.toInt(), parseTime(m.group(1)!!), m.group(4)!!, m.group(5)!!, m.group(6)!!)
        } else {
            null
        }
    }

    private data class LogLine(val pid: Int, val tid: Int, val time: Date?, val level: String, val tag: String, var msg: String)

    /**
     * Match a single line of `logcat -v threadtime`, such as:
     *
     * <pre>05-26 11:02:36.886 5689 5689 D AndroidRuntime: CheckJNI is OFF.</pre>
     */
    private val THREADTIME_LINE: Pattern = Pattern.compile("^(\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}.\\d{3})(?:\\s+[0-9A-Za-z]+)?\\s+(\\d+)\\s+(\\d+)\\s+([A-Z])\\s+(.+?)\\s*: (.*)$")

    fun saveToFile(priority: String, component: String, message: String, time: Date?) {
        val p = when (priority) {
            "E" -> "E"
            "W" -> "W"
            else -> " "
        }
        val date = time?.let { Logger.dateFormat.format(Instant.ofEpochMilli(time.time)) } ?: Logger.dateFormat.format(Instant.now())
        val line = "$date $p ${component.padEnd(10).slice(0..9)} $message"
        logToFile(line)
    }

    fun logToFile(line: String) {
        file.append(handle, line, maxSizeKb = MAX_LOG_SIZE_KB)
    }

    fun showLog() {
        val log = file.load(handle)

        val builder = AlertDialog.Builder(context.requireContext())
        builder.setTitle("Blokada Log")
        builder.setMessage(log.takeLast(500).reversed().joinToString("\n"))
        builder.setPositiveButton("Close") { dialog, _ ->
            dialog.dismiss()
        }
        builder.setNeutralButton("Share") { dialog, _ ->
            dialog.dismiss()
            shareLog()
        }
        val dialog = builder.show()

        // Use smaller font and monospace
        val view: TextView? = dialog.findViewById(android.R.id.message)
        view?.let {
            it.textSize = 8f
            it.typeface = Typeface.create("monospace", Typeface.NORMAL)
        }
    }

    private fun preShareLog() {
        Logger.w("Log", "Printing debug information for log sharing")
        Logger.v("Log", EnvironmentService.getUserAgent())
        Logger.v("Log", EnvironmentService.getDeviceAlias())
        Logger.v("Log", "Local time: ${formatter.format(Calendar.getInstance().time)}")
        onShareLogCallbacks.forEach {
            Logger.v("Log", "Printing for callback ${it.key}")
            it.value.printDebugInfo()
        }
    }

    fun shareLog() {
        preShareLog()
        Logger.w("Log", "Sharing log")
        val ctx = context.requireContext()
        val uri = File(handle)
        val actualUri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.files", uri)

        val activity = ctx as? Activity
        if (activity != null) {
            val intent = ShareCompat.IntentBuilder.from(activity)
                .setStream(actualUri)
                .setType("text/*")
                .intent
                .setAction(Intent.ACTION_SEND)
                .setDataAndType(actualUri, "text/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
        } else {
            val openFileIntent = Intent(Intent.ACTION_SEND)
            openFileIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            openFileIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            openFileIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            openFileIntent.type = "plain/*"
            openFileIntent.putExtra(Intent.EXTRA_STREAM, actualUri)
            ctx.startActivity(openFileIntent)
        }
    }

    private fun shareLogAlternative() {
        val ctx = context.requireContext()
        val uri = File(handle)
        val openFileIntent = Intent(Intent.ACTION_SEND)
        openFileIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        openFileIntent.type = "plain/*"
        openFileIntent.putExtra(Intent.EXTRA_STREAM,
            FileProvider.getUriForFile(ctx, "${ctx.packageName}.files",
                uri))
        ctx.startActivity(openFileIntent)
    }

    fun setup() {
        val log = Logger("")
        log.v("*** *************** ***")
        log.v("*** BLOKADA STARTED ***")
        log.v("*** *************** ***")
        log.v(EnvironmentService.getUserAgent())
        log.v("Local time: ${formatter.format(Calendar.getInstance().time)}")
        UncaughtExceptionService.setup()
    }

    fun markLog() {
        val log = Logger("")
        log.v("*** MARKING LOG ***")
        log.v("Local time: ${formatter.format(Calendar.getInstance().time)}")
    }

}

class RestartJob : JobService() {

    private val log = Logger("Restart")

    override fun onStartJob(params: JobParameters?): Boolean {
        // This should be enough, MainApplication does the init
        log.w("Received restart job")
        jobFinished(params, false)
        return true
    }

    override fun onStopJob(params: JobParameters?) = true

}

interface PrintsDebugInfo {
    fun printDebugInfo()
}

private const val MAX_LOG_SIZE_KB = 1024
