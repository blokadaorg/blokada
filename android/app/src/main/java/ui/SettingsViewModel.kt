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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.*
import model.Defaults
import engine.EngineService
import service.PersistenceService
import ui.utils.cause
import utils.Logger
import java.lang.Exception
import org.blokada.R
import repository.DnsDataSource

class SettingsViewModel : ViewModel() {

    private val log = Logger("Settings")
    private val persistence = PersistenceService

    private val _dnsEntries = MutableLiveData<DnsWrapper>()
    val dnsEntries: LiveData<List<Pair<DnsId, Dns>>> = _dnsEntries.map { entry ->
        entry.value.map { it.id to it }
    }

    private val _localConfig = MutableLiveData<LocalConfig>()
    val localConfig = _localConfig.distinctUntilChanged()
    val selectedDns = localConfig.map { it.dnsChoice }

    private val _syncableConfig = MutableLiveData<SyncableConfig>()
    val syncableConfig = _syncableConfig

    init {
        _localConfig.value = persistence.load(LocalConfig::class)
        _syncableConfig.value = persistence.load(SyncableConfig::class)
        _dnsEntries.value = persistence.load(DnsWrapper::class)
        log.v("Config: ${_localConfig.value}")
    }

    fun setFirstTimeSeen() {
        log.v("Marking first time as seen")
        _syncableConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(notFirstRun = true)
                persistence.save(new)
                _syncableConfig.value = new
            }
        }
    }

    fun setRatedApp() {
        log.v("Marking app as rated")
        _syncableConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(rated = true)
                persistence.save(new)
                _syncableConfig.value = new
            }
        }
    }

    fun getUseChromeTabs(): Boolean {
        return _localConfig.value?.useChromeTabs ?: false
    }

    fun setUseChromeTabs(use: Boolean) {
        log.v("Switching the use of Chrome Tabs: $use")
        _localConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(useChromeTabs = use)
                persistence.save(new)
                _localConfig.value = new
            }
        }
    }

    fun getTheme(): Int? {
        return _localConfig.value?.let {
            when (it.themeName) {
                THEME_RETRO_KEY -> R.style.Theme_Blokada_Retro
                else -> when (it.useDarkTheme) {
                    true -> R.style.Theme_Blokada_Dark
                    false -> R.style.Theme_Blokada_Light
                    else -> null
                }
            }
        }
    }

    fun setUseDarkTheme(useDarkTheme: Boolean?) {
        log.v("Setting useDarkTheme: $useDarkTheme")
        _localConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(
                    useDarkTheme = useDarkTheme,
                    themeName = null
                )
                persistence.save(new)
                _localConfig.value = new
            }
        }
    }

    fun setUseTheme(name: String) {
        log.v("Setting useTheme: $name")
        _localConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(
                    useDarkTheme = null,
                    themeName = name
                )
                persistence.save(new)
                _localConfig.value = new
            }
        }
    }

    fun getLocale(): String? {
        return _localConfig.value?.locale
    }

    fun setLocale(locale: String?) {
        log.v("Setting locale: $locale")
        _localConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(locale = locale)
                persistence.save(new)
                _localConfig.value = new
            }
        }
    }

    fun setUseBackup(backup: Boolean) {
        log.v("Setting use cloud backup: $backup")
        _localConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(backup = backup)
                persistence.save(new)
                _localConfig.value = new
            }
        }
    }

    fun setEscaped(escaped: Boolean) {
        log.v("Setting escaped: $escaped")
        _localConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(escaped = escaped)
                persistence.save(new)
                _localConfig.value = new
            }
        }
    }

    fun setUseForegroundService(use: Boolean) {
        log.v("Setting use Foreground Service: $use")
        _localConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(useForegroundService = use)
                persistence.save(new)
                _localConfig.value = new
            }
        }
    }

    fun getUseForegroundService(): Boolean {
        return _localConfig.value?.useForegroundService ?: false
    }

    fun setPingToCheckNetwork(use: Boolean) {
        log.v("Setting pingToCheckNetwork: $use")
        _localConfig.value?.let { current ->
            viewModelScope.launch {
                val new = current.copy(pingToCheckNetwork = use)
                persistence.save(new)
                _localConfig.value = new
            }
        }
    }
}

const val THEME_RETRO_KEY = "retro"
const val THEME_RETRO_NAME = "Retro"