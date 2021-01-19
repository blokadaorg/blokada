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