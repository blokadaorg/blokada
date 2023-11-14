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

// We need a separate handler for notlibre because somehow exceptions in Taskers also reach out
// here as unexpected exceptions (and they are handled normally by the Tasker also). This would
// cause the app to terminate when unnecessary.
// The drawback is that once an actual unexpected crash happens, the app just logs it and freezes.
object UncaughtExceptionService: FlavorSpecific {

    private val context by lazy { ContextService }
    private const val filename = "blokada-a6.crash"

    fun setup() {
        Thread.setDefaultUncaughtExceptionHandler { _, ex ->
            val file = File(context.requireAppContext().filesDir, filename)
            file.writeText(getFatalMessage(ex))
        }
    }

    private fun getFatalMessage(ex: Throwable): String {
        return """
            |Fatal from Android:
            |${ex.message}
            |${ex.stackTraceToString()}
            |${ex.cause?.message}
            |${ex.cause?.stackTraceToString()}
            |""".trimMargin()
    }
}