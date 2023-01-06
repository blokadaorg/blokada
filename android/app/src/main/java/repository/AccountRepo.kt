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
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import model.Account
import model.Tab
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
    private val writePreviousAccount = MutableStateFlow<Account?>(null)

    val accountHot = writeAccount.filterNotNull()
    val previousAccountHot = writePreviousAccount
    val accountIdHot = accountHot.map { it.id }.distinctUntilChanged()
    val accountTypeHot = accountHot.map { it.type.toAccountType() }.distinctUntilChanged()

    val activeTabHot by lazy { Repos.nav.activeTabHot }

    fun start() {
        //GlobalScope.launch { hackyAccount() }
        onSettingsTab_refreshAccount()
    }

    fun hackyAccount() {
        accountVm.account.observeForever {
            val previous = writeAccount.value
            writePreviousAccount.value = previous
            writeAccount.value = it
        }
    }

    fun onSettingsTab_refreshAccount() {
        GlobalScope.launch {
            activeTabHot.filter { it == Tab.Settings }
            .debounce(1000)
            .collect {
                accountVm.refreshAccount()
            }
        }
    }

}