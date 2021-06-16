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
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.util.Log
import android.widget.TextView
import androidx.core.app.ShareCompat
import androidx.core.content.FileProvider
import ui.utils.cause
import utils.Logger
import java.io.File
import kotlin.system.exitProcess

object LogService {

    private val context = ContextService
    private val file = FileService

    fun onShareLog(name: String, run: PrintsDebugInfo) {
        Logger.v("Log", "Adding onShareLog callback for $name")
        onShareLogCallbacks += name to run
    }

    private var onShareLogCallbacks = emptyMap<String, PrintsDebugInfo>()

    private val handle by lazy {
        val handle = file.commonDir().file("blokada5.log.txt")
        Log.println(Log.VERBOSE, "Logger", "Logger will log to file: $handle")
        handle
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
        handleUncaughtExceptions()
    }

    private fun handleUncaughtExceptions() {
        Thread.setDefaultUncaughtExceptionHandler { _, ex ->
            Logger.e("Fatal", "Uncaught exception, restarting app".cause(ex))
            startThroughJobScheduler()
            exitProcess(-1)
        }
    }

    private fun startThroughJobScheduler() {
        try {
            val ctx = context.requireContext()
            val scheduler = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            val serviceComponent = ComponentName(ctx, RestartJob::class.java)
            val builder = JobInfo.Builder(0, serviceComponent)
            builder.setOverrideDeadline(3 * 1000L)
            scheduler.schedule(builder.build())
            Logger.v("Restart", "Scheduled restart in 3s (will not work on all devices)")
        } catch (ex: Exception) {
            Logger.e("Restart", "Could not restart app after fatal".cause(ex))
        }
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
