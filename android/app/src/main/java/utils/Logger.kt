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

package utils

import android.util.Log
import binding.CommandBinding
import channel.command.CommandName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.time.ZoneId
import java.time.format.DateTimeFormatter

open class Logger(private val component: String) {

    open fun e(message: String) = Logger.e(component, message)
    open fun w(message: String) = Logger.w(component, message)
    open fun v(message: String) = Logger.v(component, message)

    companion object {
        private val scope = CoroutineScope(Dispatchers.Main)
        private val commands by lazy { CommandBinding }

        fun e(component: String, message: String) {
            scope.launch {
                commands.execute(CommandName.ERROR, "[$component] $message")
            }
        }

        fun w(component: String, message: String) {
            scope.launch {
                commands.execute(CommandName.WARNING, "[$component] $message")
            }
        }

        fun v(component: String, message: String) {
            logcatLine(2, component, message)
        }

        private fun logcatLine(priority: Int, component: String, message: String) {
            Log.println(priority, component, message)
        }
    }

}