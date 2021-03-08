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
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import blocka.LegacyAccountImport
import com.akexorcist.localizationactivity.ui.LocalizationApplication
import engine.EngineService
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import model.BlockaRepoConfig
import model.BlockaRepoPayload
import engine.FilteringService
import model.BlockaConfig
import service.*
import ui.advanced.packs.PacksViewModel
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

    override fun onCreate() {
        super.onCreate()
        ContextService.setContext(this)
        LegacyAccountImport.setup()
        LogService.setup()
        DozeService.setup(this)
        setupEvents()
        MonitorService.setup(settingsVM.getUseForegroundService())
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

        accountVM.account.observeForever { account ->
            tunnelVM.checkConfigAfterAccountChanged(account)
        }

        settingsVM.localConfig.observeForever {
            EnvironmentService.escaped = it.escaped
            TranslationService.setLocale(it.locale)
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

        statsVM.stats.observeForever { stats ->
            // Not sure how it can be null, but there was a crash report
            stats?.let { stats ->
                MonitorService.setStats(stats)
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
            BlocklistService.setup()
            packsVM.setup()
            FilteringService.reload()
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