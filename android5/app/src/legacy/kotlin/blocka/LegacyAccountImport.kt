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

package blocka

import io.paperdb.Paper
import model.Account
import model.AccountId
import service.ContextService
import utils.Logger

@Deprecated("This is only a temporary legacy import")
object LegacyAccountImport {

    fun setup() {
        val context = ContextService.requireContext()
        Paper.init(context)
    }

    fun importLegacyAccount(): Account? {
        val key = "current-account"
        return try {
            val currentAccount: CurrentAccount = Paper.book().read(key)
            Paper.book().delete(key)
            Logger.w("Legacy", "Using legacy imported account ID")
            Account(id = currentAccount.id)
        } catch (ex: Exception) {
            null
        }
    }

}

// In the case of PaperDB, the persisted class has to have exactly
// same package name
data class CurrentAccount(
    val id: String = ""//,
    //val activeUntil: Date = Date(0),
//    val privateKey: String = "",
//    val publicKey: String = "",
//    val lastAccountCheck: Long = 0,
//    val accountOk: Boolean = false,
//    val migration: Int = 0,
//    val unsupportedForVersionCode: Int = 0
)