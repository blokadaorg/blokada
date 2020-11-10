/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package utils

import android.util.Log
import service.FileService
import service.LogService
import service.file
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class Logger(private val component: String) {

    fun e(message: String) = Logger.e(component, message)
    fun w(message: String) = Logger.w(component, message)
    fun v(message: String) = Logger.v(component, message)

    companion object {

        private val dateFormat = DateTimeFormatter.ofPattern("HH:mm:ss.SSS")
            .withZone(ZoneId.of("UTC"))

        fun e(component: String, message: String) {
            saveToFile(6, component, message)
            logcatLine(6, component, message)
        }

        fun w(component: String, message: String) {
            saveToFile(5, component, message)
            logcatLine(5, component, message)
        }

        fun v(component: String, message: String) {
            saveToFile(2, component, message)
            logcatLine(2, component, message)
        }

        private fun logcatLine(priority: Int, component: String, message: String) {
            Log.println(priority, component, message)
        }

        fun saveToFile(priority: Int, component: String, message: String) {
            val p = when (priority) {
                6 -> "E"
                5 -> "W"
                else -> " "
            }
            val date = dateFormat.format(Instant.now())
            val line = "$date $p ${component.padEnd(10).slice(0..9)} $message"
            LogService.logToFile(line)
        }
    }

}
