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
import binding.AccountPaymentBinding
import binding.AppBinding
import binding.CommandBinding
import binding.CommonBinding
import binding.CoreBinding
import binding.FamilyBinding
import binding.PermBinding
import binding.StageBinding
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import repository.Repos
import service.BlocklistService
import service.ConnectivityService
import service.ContextService
import service.DozeService
import service.FlutterService

class MainApplication: Application(), ViewModelStoreOwner {

    private lateinit var networksVM: NetworksViewModel

    private val flutter by lazy { FlutterService }
    private lateinit var commands: CommandBinding
    private lateinit var stage: StageBinding
    private lateinit var http: CommonBinding
    private lateinit var tracer: CoreBinding
    private lateinit var app: AppBinding
    private lateinit var accountPayment: AccountPaymentBinding
    private lateinit var perm: PermBinding
    private lateinit var family: FamilyBinding

    override val viewModelStore: ViewModelStore
        get() = MainApplication.viewModelStore

    override fun onCreate() {
        super.onCreate()
        ContextService.setApp(this)
        setupCommonModule()

        DozeService.setup(this)
        setupEvents()
        Repos.start()
    }

    private fun setupCommonModule() {
        flutter.setup()

        // Need references for the bindings to get initialized
        commands = CommandBinding
        stage = StageBinding
        app = AppBinding
        http = CommonBinding
        tracer = CoreBinding
        accountPayment = AccountPaymentBinding
        perm = PermBinding
        family = FamilyBinding
    }

    private fun setupEvents() {
        networksVM = ViewModelProvider(this).get(NetworksViewModel::class.java)

        ConnectivityService.setup()

        GlobalScope.launch {
//            Services.payment.setup()
            BlocklistService.setup()
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