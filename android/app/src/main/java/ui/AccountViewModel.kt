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
import model.*
import org.blokada.R
import service.*
import ui.utils.cause
import ui.utils.now
import utils.Logger
import java.util.*

class AccountViewModel: ViewModel() {

    private val log = Logger("Account")
    private val blocka = BlockaApiService
    private val persistence = PersistenceService
    private val alert = AlertDialogService
    private val connectivity = ConnectivityService

    private val _account = MutableLiveData<Account>()
    val account: LiveData<Account> = _account
    val accountExpiration: LiveData<ActiveUntil> = _account.map { it.active_until }.distinctUntilChanged()

    // This var is thread safe because we work on Main.immediate dispatched coroutines
    private var requestOngoing = false
    private var lastAccountRefresh = 0L

    init {
        try {
            updateLiveData(persistence.load(Account::class))
            log.v("Loaded account from persistence")
        } catch (ex: Exception) {}
    }

    fun restoreAccount(accountId: AccountId) {
        viewModelScope.launch {
            log.w("Restoring account")
            try {
                val accountId = accountId.toLowerCase(Locale.ENGLISH).trim()
                val account = blocka.getAccount(accountId)
                if (EnvironmentService.isPublicBuild() && !account.isActive()) throw BlokadaException("Account inactive after restore")
                updateLiveData(account)
            } catch (ex: BlokadaException) {
                log.e("Failed restoring account".cause(ex))
                updateLiveData(persistence.load(Account::class))
                alert.showAlert(R.string.error_account_inactive_after_restore)
            }
        }
    }

    fun refreshAccount(accountExpiring: Boolean = false) {
        viewModelScope.launch {
            try {
                log.v("Refreshing account")
                requestOngoing = true
                val accountId = _account.value?.id ?: persistence.load(Account::class).id
                val account = blocka.getAccount(accountId)
                updateLiveData(account)
                log.v("Account refreshed, active: ${account.isActive()}, type: ${account.type}")
                lastAccountRefresh = now()
                requestOngoing = false
            } catch (ex: NoPersistedAccount) {
                log.w("No account to refresh yet, ignoring")
                requestOngoing = false
            } catch (ex: BlokadaException) {
                requestOngoing = false
                when {
                    accountExpiring -> {
                        log.w("Could not refresh expiring account, assuming expired".cause(ex))
                        account.value?.copy(
                            active_until = Date(0),
                            active = false,
                            type = null
                        )?.run {
                            updateLiveData(this)
                        }
                    }
                    connectivity.isDeviceInOfflineMode() ->
                        log.w("Could not refresh account but device is offline, ignoring")
                    else -> {
                        // TODO: better handling?
                        log.w("Could not refresh account, ignoring".cause(ex))
                    }
                }

                try {
                    log.v("Returning persisted copy")
                    updateLiveData(persistence.load(Account::class))
                } catch (ex: Exception) {}
            }
        }
    }

    fun maybeRefreshAccount() {
        viewModelScope.launch {
            if (requestOngoing) {
                log.v("maybeRefreshAccount: Account request already in progress, ignoring")
            } else if (!hasAccount()) {
                try {
                    log.w("Creating new account")
                    requestOngoing = true
                    val account = blocka.postNewAccount()
                    updateLiveData(account)
                    requestOngoing = false
                } catch (ex: Exception) {
                    requestOngoing = false
                    log.w("Could not create account".cause(ex))
                    alert.showAlert(R.string.error_creating_account)
                }
            } else if (!EnvironmentService.isFdroid() && now() > lastAccountRefresh + ACCOUNT_REFRESH_MILLIS) {
                log.v("Account is stale, refreshing")
                refreshAccount()
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

    private fun updateLiveData(account: Account) {
        persistence.save(account)
        viewModelScope.launch {
            _account.value = account
        }
    }

}

private const val ACCOUNT_REFRESH_MILLIS = 10 * 60 * 1000 // Same as on iOS
