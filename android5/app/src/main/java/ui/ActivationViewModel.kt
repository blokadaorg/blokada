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
import model.ActiveUntil
import service.ExpirationService
import service.PersistenceService
import utils.Logger
import java.util.*

class ActivationViewModel: ViewModel() {

    enum class ActivationState {
        INACTIVE, PURCHASING, JUST_PURCHASED, JUST_ACTIVATED, ACTIVE, JUST_EXPIRED
    }

    private val log = Logger("Activation")
    private val persistence = PersistenceService
    private val expiration = ExpirationService

    private val _state = MutableLiveData<ActivationState>()
    val state: LiveData<ActivationState> = _state.distinctUntilChanged()

    init {
        viewModelScope.launch {
            _state.value = persistence.load(ActivationState::class)
        }
        expiration.onExpired = {
            setExpiration(Date(0))
        }
    }

    fun setExpiration(activeUntil: ActiveUntil) {
        viewModelScope.launch {
            _state.value?.let { state ->
                val active = !activeUntil.beforeNow()
                when {
                    !active && state != ActivationState.INACTIVE -> {
                        log.w("Account just expired")
                        updateLiveData(ActivationState.JUST_EXPIRED)
                    }
                    active && state == ActivationState.INACTIVE -> {
                        log.w("Account is active")
                        updateLiveData(ActivationState.ACTIVE)
                    }
                    active && state == ActivationState.PURCHASING -> {
                        log.w("Account is active after purchase flow, activation succeeded")
                        updateLiveData(ActivationState.JUST_ACTIVATED)
                    }
                    active && state == ActivationState.JUST_PURCHASED -> {
                        log.w("Account is active after refresh, activation succeeded")
                        updateLiveData(ActivationState.JUST_ACTIVATED)
                    }
                    active && state == ActivationState.JUST_EXPIRED -> {
                        log.w("Account got activated after just expired, a bit weird case")
                        updateLiveData(ActivationState.ACTIVE)
                    }
                }

                if (active) expiration.setExpirationAlarm(activeUntil)
            }
        }
    }

    fun setStartedPurchaseFlow() {
        viewModelScope.launch {
            log.w("User started purchase flow")
            updateLiveData(ActivationState.PURCHASING)
        }
    }

    fun maybeRefreshAccountAfterUrlVisited(url: String) {
        viewModelScope.launch {
            _state.value?.let { state ->
                // If we notice our payment gateway loaded the success url, we refresh account info
                if (state == ActivationState.INACTIVE && url == SUCCESS_URL) {
                    log.w("Payment succeeded, marking account to refresh")
                    updateLiveData(ActivationState.JUST_PURCHASED)
                }
            }
        }
    }

    fun maybeRefreshAccountAfterOnResume() {
        viewModelScope.launch {
            _state.value?.let { state ->
                if (state == ActivationState.PURCHASING) {
                    // Assume user might just have purchased (no harm if we are wrong)
                    log.w("User is back from purchase flow, marking account to refresh")
                    updateLiveData(ActivationState.JUST_PURCHASED)
                }
            }
        }
    }

    fun setInformedUserAboutActivation() {
        viewModelScope.launch {
            log.w("Informed user about activation, setting to active")
            updateLiveData(ActivationState.ACTIVE)
        }
    }

    fun setInformedUserAboutExpiration() {
        viewModelScope.launch {
            log.w("Informed user about expiration, setting to inactive")
            updateLiveData(ActivationState.INACTIVE)
        }
    }

    private fun updateLiveData(state: ActivationState) {
        viewModelScope.launch {
            _state.value = state
            persistence.save(state)
        }
    }
}

fun Date.beforeNow(): Boolean {
    return this.before(Date())
}

private const val SUCCESS_URL = "https://app.blokada.org/success"
