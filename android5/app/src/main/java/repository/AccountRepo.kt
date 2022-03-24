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

package repository

import androidx.lifecycle.ViewModelProvider
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import model.Account
import model.toAccountType
import service.ContextService
import ui.AccountViewModel
import ui.MainApplication

class AccountRepo {

    private val context = ContextService

    // TODO: This a hacky temporary way, it should be AccountRepo, maybe broke BackupAgent
    private val accountVm by lazy {
        val app = context.requireApp() as MainApplication
        ViewModelProvider(app).get(AccountViewModel::class.java)
    }

    private val writeAccount = MutableStateFlow<Account?>(null)

    val accountHot = writeAccount.filterNotNull()
    val accountIdHot = accountHot.map { it.id }.distinctUntilChanged()
    val accountTypeHot = accountHot.map { it.type.toAccountType() }.distinctUntilChanged()

    fun start() {
        GlobalScope.launch { hackyAccount() }
    }

    suspend fun hackyAccount() {
        accountVm.account.observeForever {
            writeAccount.value = it
        }
    }
}