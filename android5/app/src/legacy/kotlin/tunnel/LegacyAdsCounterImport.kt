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

package tunnel

import android.content.Context
import io.paperdb.Paper
import model.AdsCounter
import service.ContextService
import utils.Logger

@Deprecated("This is only a temporary legacy import")
object LegacyAdsCounterImport {

    fun importLegacyCounter(): AdsCounter? {
        return try {
            val ctx = ContextService.requireContext()
            val p = ctx.getSharedPreferences("default", Context.MODE_PRIVATE)

            val key = "LogConfig"
            val legacy4 = try {
                val config: LogConfig = Paper.book().read(key)
                Paper.book().delete(key)
                config.dropCount
            } catch (ex: Exception) {
                null
            }

            var legacy3: Int? = p.getInt("tunnelAdsCount", -1)
            if (legacy3 != -1) p.edit().remove("tunnelAdsCount").apply()
            else legacy3 = null

            if (legacy4 != null) {
                Logger.w("Legacy", "Using legacy ads counter from v4")
                AdsCounter(persistedValue = legacy4.toLong())
            } else if (legacy3 != null) {
                Logger.w("Legacy", "Using legacy ads counter from v3")
                AdsCounter(persistedValue = legacy3.toLong())
            } else null
        } catch (ex: Exception) {
            null
        }
    }

}

// In the case of PaperDB, the persisted class has to have exactly
// same package name
data class LogConfig(
//    val logActive: Boolean = true,
//    val csvLogAllowed: Boolean = false,
//    val csvLogDenied: Boolean = false,
    val dropCount: Int = 0//,
//    val dropStart: Long = System.currentTimeMillis()
)