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

package ui

import androidx.lifecycle.*
import kotlinx.coroutines.launch
import model.Account
import model.AccountId
import model.ActiveUntil
import model.BlokadaException
import org.blokada.R
import repository.BlockaRepository
import service.AlertDialogService
import service.ConnectivityService
import service.EnvironmentService
import service.PersistenceService
import ui.utils.cause
import utils.Logger
import java.util.*

class AccountViewModel: ViewModel() {

    private val log = Logger("Account")
    private val blocka = BlockaRepository
    private val persistence = PersistenceService
    private val alert = AlertDialogService
    private val connectivity = ConnectivityService

    private val _account = MutableLiveData<Account>()
    val account: LiveData<Account> = _account
    val accountExpiration: LiveData<ActiveUntil> = _account.map { it.active_until }.distinctUntilChanged()

    init {
        viewModelScope.launch {
            log.v("Refreshing account after start")
            refreshAccount()
        }
    }

    fun restoreAccount(accountId: AccountId) {
        viewModelScope.launch {
            log.w("Restoring account")
            try {
                val accountId = accountId.toLowerCase(Locale.ENGLISH).trim()
                val account = blocka.fetchAccount(accountId)
                if (EnvironmentService.isPublicBuild() && !account.isActive()) throw BlokadaException("Account inactive after restore")
                updateLiveData(account)
            } catch (ex: BlokadaException) {
                log.e("Failed restoring account".cause(ex))
                updateLiveData(persistence.load(Account::class))
                alert.showAlert(R.string.error_account_inactive_after_restore)
            }
        }
    }

    fun refreshAccount() {
        viewModelScope.launch {
            try {
                log.v("Refreshing account")
                refreshAccountInternal()
            } catch (ex: BlokadaException) {
                when {
                    connectivity.isDeviceInOfflineMode() ->
                        log.w("Could not refresh account but device is offline, ignoring")
                    else -> {
                        log.e("Could not refresh account, TODO".cause(ex))
                    }
                }

                try {
                    log.v("Returning persisted copy")
                    updateLiveData(persistence.load(Account::class))
                } catch (ex: Exception) {}
            }
        }
    }

    fun checkAccount() {
        viewModelScope.launch {
            if (!hasAccount())
                try {
                    createAccount()
                } catch (ex: Exception) {
                    log.w("Could not create account".cause(ex))
                    alert.showAlert(R.string.error_creating_account)
                }
        }
    }

    fun isActive(): Boolean {
        return account.value?.isActive() ?: false
    }

    private fun hasAccount() = try {
        persistence.load(Account::class)
        true
    } catch (ex: Exception) { false }

    private suspend fun createAccount(): Account {
        log.w("Creating new account")
        val account = blocka.createAccount()
        updateLiveData(account)
        return account
    }

    private suspend fun refreshAccountInternal(): Account {
        val accountId = _account.value?.id ?: persistence.load(Account::class).id
        val account = blocka.fetchAccount(accountId)
        updateLiveData(account)
        log.v("Account refreshed")
        return account
    }

    private fun updateLiveData(account: Account) {
        persistence.save(account)
        viewModelScope.launch {
            _account.value = account
        }
    }

}