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

import utils.FlavorSpecific
import java.io.File
import java.util.Date
import kotlin.system.exitProcess

object UncaughtExceptionService: FlavorSpecific {

    private val env by lazy { EnvironmentService }
    private val context by lazy { ContextService }
    private const val filename = "blokada-a6.crash"
    private var defaultUEH: Thread.UncaughtExceptionHandler? = null



    fun setup() {
        defaultUEH = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, ex ->
            val file = File(context.requireAppContext().filesDir, filename)
            file.writeText(getFatalMessage(ex))
            defaultUEH?.run {
                this.uncaughtException(thread, ex)
            } ?: run {
                exitProcess(2)
            }
        }
    }

    private fun getFatalMessage(ex: Throwable): String {
        return """
            |# Blokada 6 for Android # Fatal Report # v0.1
            |${Date()}
            |${env.getUserAgent()}
            |${ex.message}
            |${ex.stackTraceToString()}
            |${ex.cause?.message}
            |${ex.cause?.stackTraceToString()}
            |""".trimMargin()
    }
}