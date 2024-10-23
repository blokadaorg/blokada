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
import android.app.Application
import android.app.Service
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import binding.AccountBinding
import binding.AccountPaymentBinding
import binding.AppBinding
import binding.CommandBinding
import binding.CustomBinding
import binding.DeviceBinding
import binding.EnvBinding
import binding.FilterBinding
import binding.HttpBinding
import binding.JournalBinding
import binding.LinkBinding
import binding.LoggerBinding
import binding.NotificationBinding
import binding.PermBinding
import binding.PersistenceBinding
import binding.RateBinding
import binding.StageBinding
import binding.StatsBinding
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import model.BlockaRepoConfig
import model.BlockaRepoPayload
import repository.Repos
import service.AppUninstallService
import service.BlocklistService
import service.ConnectivityService
import service.ContextService
import service.DozeService
import service.FlutterService
import service.MonitorService
import service.PersistenceService
import service.TranslationService
import service.UpdateService
import ui.advanced.decks.PacksViewModel
import ui.utils.cause
import utils.Logger

class MainApplication: Application(), ViewModelStoreOwner {

    private lateinit var settingsVM: SettingsViewModel
    private lateinit var blockaRepoVM: BlockaRepoViewModel
//    private lateinit var adsCounterVM: AdsCounterViewModel
    private lateinit var networksVM: NetworksViewModel
    private lateinit var packsVM: PacksViewModel

    private val flutter by lazy { FlutterService }
    private lateinit var commands: CommandBinding
    private lateinit var stage: StageBinding
    private lateinit var env: EnvBinding
    private lateinit var persistence: PersistenceBinding
    private lateinit var http: HttpBinding
    private lateinit var tracer: LoggerBinding
    private lateinit var app: AppBinding
    private lateinit var notification: NotificationBinding
    private lateinit var account: AccountBinding
    private lateinit var accountPayment: AccountPaymentBinding
    private lateinit var device: DeviceBinding
    private lateinit var journal: JournalBinding
    private lateinit var custom: CustomBinding
    private lateinit var filter: FilterBinding
    private lateinit var perm: PermBinding
    private lateinit var rate: RateBinding
    private lateinit var stats: StatsBinding
    private lateinit var link: LinkBinding

    private val appUninstall = AppUninstallService()

    override val viewModelStore: ViewModelStore
        get() = MainApplication.viewModelStore

    override fun onCreate() {
        super.onCreate()
        ContextService.setApp(this)
        setupCommonModule()

        DozeService.setup(this)
        setupEvents()
        MonitorService.setup(false)
        Repos.start()
    }

    private fun setupCommonModule() {
        flutter.setup()

        // Need references for the bindings to get initialized
        commands = CommandBinding
        stage = StageBinding
        app = AppBinding
        env = EnvBinding
        persistence = PersistenceBinding
        http = HttpBinding
        notification = NotificationBinding
        tracer = LoggerBinding
        account = AccountBinding
        accountPayment = AccountPaymentBinding
        device = DeviceBinding
        journal = JournalBinding
        custom = CustomBinding
        filter = FilterBinding
        perm = PermBinding
        rate = RateBinding
        stats = StatsBinding
        link = LinkBinding
    }

    private fun setupEvents() {
        networksVM = ViewModelProvider(this).get(NetworksViewModel::class.java)

        settingsVM = ViewModelProvider(this).get(SettingsViewModel::class.java)
        blockaRepoVM = ViewModelProvider(this).get(BlockaRepoViewModel::class.java)
//        adsCounterVM = ViewModelProvider(this).get(AdsCounterViewModel::class.java)
        packsVM = ViewModelProvider(this).get(PacksViewModel::class.java)

//        accountVM.account.observeForever { account ->
//            tunnelVM.checkConfigAfterAccountChanged(account)
//        }

        settingsVM.localConfig.observeForever {
            TranslationService.setLocale(it.locale)
            ConnectivityService.pingToCheckNetwork = it.pingToCheckNetwork
        }

        blockaRepoVM.repoConfig.observeForever {
            maybePerformAction(it)
            UpdateService.checkForUpdate(it)
            if (ContextService.hasActivityContext())
                UpdateService.showUpdateAlertIfNecessary(
                    libreMode = false
                )
            else
                UpdateService.showUpdateNotificationIfNecessary()
        }

//        statsVM.history.observeForever {
//            // Not sure how it can be null, but there was a crash report
//            it?.let { history ->
//                MonitorService.setHistory(history)
//            }
//        }
//
//        statsVM.stats.observeForever {
//            // Not sure how it can be null, but there was a crash report
//            it?.let { stats ->
//                adsCounterVM.setRuntimeCounter(stats.denied.toLong())
//            }
//        }

//        adsCounterVM.counter.observeForever {
//            MonitorService.setCounter(it)
//        }
//
        networksVM.activeConfig.observeForever {
            GlobalScope.launch {
                // Without the foreground service, we will get killed while switching the VPN.
                // The simplest solution is to force the flag (which will apply from the next
                // app start). Not the nicest though.
                if (networksVM.hasCustomConfigs() && !settingsVM.getUseForegroundService())
                    settingsVM.setUseForegroundService(true)
            }
        }
        ConnectivityService.setup()

        GlobalScope.launch {
//            Services.payment.setup()
            BlocklistService.setup()
        }

        GlobalScope.launch { onAppStateChanged_updateMonitorService() }
        GlobalScope.launch { onAppStateWorking_updateMonitorService() }
        GlobalScope.launch { onAppStateActive_maybeUninstallOtherApps() }
        checkOtherAppsInstalled()
    }

    private suspend fun onAppStateChanged_updateMonitorService() {
        app.appStatus.collect {
            MonitorService.setAppState(it)
        }
    }

    private suspend fun onAppStateWorking_updateMonitorService() {
        app.working.collect {
            it?.let {
                MonitorService.setWorking(it)
            }
        }
    }

    private suspend fun onAppStateActive_maybeUninstallOtherApps() {
//        appRepo.appStateHot.filter { it == AppState.Activated }
//        .collect {
//            appUninstall.maybePromptToUninstall()
//        }
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

    companion object {
        /**
         * Not sure if doing it right, but some ViewModel in our app should be scoped to the
         * application, since they are relevant for when the app is started by the SystemTunnel
         * (as apposed to MainActivity). This probably would be solved better if some LiveData
         * objects within some of the ViewModels would not be owned by them.
         */
        val viewModelStore = ViewModelStore()
    }

}

fun Activity.app(): MainApplication {
    return application as MainApplication
}

fun Service.app(): MainApplication {
    return application as MainApplication
}