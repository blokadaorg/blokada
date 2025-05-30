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
import android.os.Build
import androidx.appcompat.app.AppCompatDelegate
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStoreFile
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import binding.AppBinding
import binding.CommandBinding
import binding.CommonBinding
import binding.CoreBinding
import binding.PaymentBinding
import binding.PermBinding
import binding.PlusBinding
import binding.StageBinding
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.configStore.FileConfigStore
import com.wireguard.android.model.TunnelManager
import com.wireguard.android.util.RootShell
import com.wireguard.android.util.ToolsInstaller
import com.wireguard.android.util.UserKnobs
import com.wireguard.android.util.applicationScope
import engine.EngineService
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import model.BlockaConfig
import repository.Repos
import service.BlocklistService
import service.ConnectivityService
import service.ContextService
import service.DozeService
import service.FlutterService
import service.PersistenceService
import utils.cause
import utils.Logger
import java.lang.ref.WeakReference

class MainApplication : Application(), ViewModelStoreOwner {

    private lateinit var networksVM: NetworksViewModel

    private val flutter by lazy { FlutterService }
    private lateinit var commands: CommandBinding
    private lateinit var stage: StageBinding
    private lateinit var env: CommonBinding
    private lateinit var tracer: CoreBinding
    private lateinit var app: AppBinding
    private lateinit var common: CommonBinding
    private lateinit var perm: PermBinding
    private lateinit var plus: PlusBinding
    private lateinit var payment: PaymentBinding

    override val viewModelStore: ViewModelStore
        get() = MainApplication.viewModelStore

    override fun onCreate() {
        super.onCreate()
        ContextService.setApp(this)
        setupCommonModule()

        DozeService.setup(this)
        wgOnCreate()
        setupEvents()
        Repos.start()
    }

    private fun setupCommonModule() {
        flutter.setup()

        // Need references for the bindings to get initialized
        commands = CommandBinding
        stage = StageBinding
        app = AppBinding
        env = CommonBinding
        common = CommonBinding
        tracer = CoreBinding
        perm = PermBinding
        plus = PlusBinding
        payment = PaymentBinding
    }

    private fun setupEvents() {
        networksVM = ViewModelProvider(this).get(NetworksViewModel::class.java)
        EngineService.setup(
            network = networksVM.getActiveNetworkConfig(),
            user = PersistenceService.load(BlockaConfig::class) // TODO: not nice
        )

        networksVM.activeConfig.observeForever {
            GlobalScope.launch {
                try {
                    EngineService.updateConfig(network = it)
                } catch (ex: Exception) {
                }
            }
        }
        ConnectivityService.setup()

        GlobalScope.launch {
            BlocklistService.setup()
        }

    }

    // Stuff taken from Wireguard
    private val futureBackend = CompletableDeferred<Backend>()
    private val coroutineScope = CoroutineScope(Job() + Dispatchers.Main.immediate)
    private var backend: Backend? = null
    private lateinit var rootShell: RootShell
    private lateinit var preferencesDataStore: DataStore<Preferences>
    private lateinit var toolsInstaller: ToolsInstaller
    private lateinit var tunnelManager: TunnelManager

    private suspend fun determineBackend(): Backend {
        var backend: Backend? = null
//        if (UserKnobs.enableKernelModule.first() && WgQuickBackend.hasKernelSupport()) {
//            try {
//                rootShell.start()
//                val wgQuickBackend = WgQuickBackend(applicationContext, rootShell, toolsInstaller)
//                wgQuickBackend.setMultipleTunnels(UserKnobs.multipleTunnels.first())
//                backend = wgQuickBackend
//                UserKnobs.multipleTunnels.onEach {
//                    wgQuickBackend.setMultipleTunnels(it)
//                }.launchIn(coroutineScope)
//            } catch (ignored: Exception) {
//            }
//        }
        if (backend == null) {
            backend = GoBackend(applicationContext)
            GoBackend.setAlwaysOnCallback {
                get().applicationScope.launch {
                    get().tunnelManager.restoreState(
                        true
                    )
                }
            }
        }
        return backend
    }

    private fun wgOnCreate() {
        rootShell = RootShell(applicationContext)
        toolsInstaller = ToolsInstaller(applicationContext, rootShell)
        preferencesDataStore =
            PreferenceDataStoreFactory.create { applicationContext.preferencesDataStoreFile("settings") }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            coroutineScope.launch {
                AppCompatDelegate.setDefaultNightMode(
                    if (UserKnobs.darkTheme.first()) AppCompatDelegate.MODE_NIGHT_YES else AppCompatDelegate.MODE_NIGHT_NO
                )
            }
        } else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
        }
        tunnelManager = TunnelManager(FileConfigStore(applicationContext))
        tunnelManager.onCreate()
        coroutineScope.launch(Dispatchers.IO) {
            try {
                backend = determineBackend()
                futureBackend.complete(backend!!)
            } catch (e: Throwable) {
                Logger.e("Main", "Failed to determine wg backend".cause(e))
            }
        }
    }

//    override fun onTerminate() {
//        coroutineScope.cancel()
//        super.onTerminate()
//    }

    init {
        weakSelf = WeakReference(this)
    }

    // Stuff taken from Wireguard
    companion object {
        private lateinit var weakSelf: WeakReference<MainApplication>

        @JvmStatic
        fun get(): MainApplication {
            return weakSelf.get()!!
        }

        @JvmStatic
        suspend fun getBackend() = get().futureBackend.await()

        @JvmStatic
        fun getRootShell() = get().rootShell

        @JvmStatic
        fun getPreferencesDataStore() = get().preferencesDataStore

        @JvmStatic
        fun getToolsInstaller() = get().toolsInstaller

        @JvmStatic
        fun getTunnelManager() = get().tunnelManager

        @JvmStatic
        fun getCoroutineScope() = get().coroutineScope

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
