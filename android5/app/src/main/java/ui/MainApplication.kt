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

import android.app.Activity
import android.app.Service
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import blocka.LegacyAccountImport
import com.akexorcist.localizationactivity.ui.LocalizationApplication
import engine.EngineService
import engine.FilteringService
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch
import model.AppState
import model.BlockaConfig
import model.BlockaRepoConfig
import model.BlockaRepoPayload
import repository.Repos
import service.*
import ui.utils.cause
import utils.Logger
import java.util.*

class MainApplication: LocalizationApplication(), ViewModelStoreOwner {

    companion object {
        /**
         * Not sure if doing it right, but some ViewModel in our app should be scoped to the
         * application, since they are relevant for when the app is started by the SystemTunnel
         * (as apposed to MainActivity). This probably would be solved better if some LiveData
         * objects within some of the ViewModels would not be owned by them.
          */
        val viewModelStore = ViewModelStore()
    }

    override fun getViewModelStore() = MainApplication.viewModelStore

    private lateinit var accountVM: AccountViewModel
    private lateinit var tunnelVM: TunnelViewModel
    private lateinit var settingsVM: SettingsViewModel
    private lateinit var blockaRepoVM: BlockaRepoViewModel
    private lateinit var statsVM: StatsViewModel
    private lateinit var adsCounterVM: AdsCounterViewModel
    private lateinit var networksVM: NetworksViewModel
    private lateinit var packsVM: PacksViewModel
    private lateinit var activationVM: ActivationViewModel

    private val appRepo by lazy { Repos.app }

    private val appUninstall = AppUninstallService()

    override fun onCreate() {
        super.onCreate()
        ContextService.setApp(this)
        LogService.setup()
        LegacyAccountImport.setup()
        DozeService.setup(this)
        setupEvents()
        MonitorService.setup(settingsVM.getUseForegroundService())
        Repos.start()
    }

    private fun setupEvents() {
        networksVM = ViewModelProvider(this).get(NetworksViewModel::class.java)
        EngineService.setup(
            network = networksVM.getActiveNetworkConfig(),
            user = PersistenceService.load(BlockaConfig::class) // TODO: not nice
        )

        accountVM = ViewModelProvider(this).get(AccountViewModel::class.java)
        tunnelVM = ViewModelProvider(this).get(TunnelViewModel::class.java)
        settingsVM = ViewModelProvider(this).get(SettingsViewModel::class.java)
        blockaRepoVM = ViewModelProvider(this).get(BlockaRepoViewModel::class.java)
        statsVM = ViewModelProvider(this).get(StatsViewModel::class.java)
        adsCounterVM = ViewModelProvider(this).get(AdsCounterViewModel::class.java)
        packsVM = ViewModelProvider(this).get(PacksViewModel::class.java)
        activationVM = ViewModelProvider(this).get(ActivationViewModel::class.java)

        accountVM.account.observeForever { account ->
            tunnelVM.checkConfigAfterAccountChanged(account)
        }

        settingsVM.localConfig.observeForever {
            EnvironmentService.escaped = it.escaped
            TranslationService.setLocale(it.locale)
            ConnectivityService.pingToCheckNetwork = it.pingToCheckNetwork
            tunnelVM.refreshStatus()
        }

        blockaRepoVM.repoConfig.observeForever {
            maybePerformAction(it)
            UpdateService.checkForUpdate(it)
            if (ContextService.hasActivityContext())
                UpdateService.showUpdateAlertIfNecessary(
                    libreMode = !(tunnelVM.config.value?.vpnEnabled ?: false)
                )
            else
                UpdateService.showUpdateNotificationIfNecessary()
        }

        statsVM.history.observeForever {
            // Not sure how it can be null, but there was a crash report
            it?.let { history ->
                MonitorService.setHistory(history)
            }
        }

        statsVM.stats.observeForever {
            // Not sure how it can be null, but there was a crash report
            it?.let { stats ->
                adsCounterVM.setRuntimeCounter(stats.denied.toLong())
            }
        }

        adsCounterVM.counter.observeForever {
            MonitorService.setCounter(it)
        }

        tunnelVM.tunnelStatus.observeForever {
            MonitorService.setTunnelStatus(it)
        }

        networksVM.activeConfig.observeForever {
            GlobalScope.launch {
                try { EngineService.updateConfig(network = it) } catch (ex: Exception) {}

                // Without the foreground service, we will get killed while switching the VPN.
                // The simplest solution is to force the flag (which will apply from the next
                // app start). Not the nicest though.
                if (networksVM.hasCustomConfigs() && !settingsVM.getUseForegroundService())
                    settingsVM.setUseForegroundService(true)
            }
        }
        ConnectivityService.setup()

        GlobalScope.launch {
            Services.payment.setup()
            BlocklistService.setup()
            packsVM.setup()
            FilteringService.reload()
        }

        GlobalScope.launch { onAppStateChanged_updateMonitorService() }
        GlobalScope.launch { onAppStateActive_maybeUninstallOtherApps() }
        checkOtherAppsInstalled()

        Repos.account.hackyAccount()
    }

    private suspend fun onAppStateChanged_updateMonitorService() {
        appRepo.appStateHot.collect {
            MonitorService.setAppState(it)
        }
    }

    private suspend fun onAppStateActive_maybeUninstallOtherApps() {
        appRepo.appStateHot.filter { it == AppState.Activated }
        .collect {
            appUninstall.maybePromptToUninstall()
        }
    }

    private fun checkOtherAppsInstalled() {
        if (appUninstall.hasOtherAppsInstalled()) {
            Logger.w("Main", "Other Blokada versions detected on device")
        }
    }

    private fun maybePerformAction(repo: BlockaRepoConfig) {
        // TODO: Maybe this method should be extracted to some separate file
        val log = Logger("Action")
        val persistence = PersistenceService
        repo.payload?.let { payload ->
            val previousPayload = persistence.load(BlockaRepoPayload::class)
            if (previousPayload == payload) {
                // Act on each payload once, this one has been acted on before.
                return
            }

            log.v("Got repo payload: ${payload.cmd}")
            try {
                startService(getIntentForCommand(payload.cmd))
            } catch (ex: Exception) {
                log.e("Could not act on payload".cause(ex))
            }

            log.v("Marking repo payload as acted on")
            persistence.save(payload)
        }
    }

    override fun getDefaultLanguage(): Locale {
        return TranslationService.getLocale()
    }

}

fun Activity.app(): MainApplication {
    return application as MainApplication
}

fun Service.app(): MainApplication {
    return application as MainApplication
}