/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import ui.utils.cause
import utils.FlavorSpecific
import utils.Logger
import kotlin.system.exitProcess

object UncaughtExceptionService: FlavorSpecific {

    private val context = ContextService

    fun setup() {
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