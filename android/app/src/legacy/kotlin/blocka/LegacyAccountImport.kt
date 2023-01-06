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

package blocka

import io.paperdb.Paper
import model.Account
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
            Account(id = currentAccount.id, active = false, type = "libre", payment_source = null)
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