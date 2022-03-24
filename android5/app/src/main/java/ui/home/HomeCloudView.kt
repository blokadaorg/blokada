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

package ui.home

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.*
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentManager
import androidx.lifecycle.*
import androidx.navigation.fragment.findNavController
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import model.AppState
import model.BlokadaException
import model.NoPermissions
import model.TunnelStatus
import org.blokada.R
import repository.Repos
import service.*
import ui.*
import ui.utils.getColorFromAttr
import utils.Links
import utils.toBlokadaPlusText
import utils.withBoldSections
import java.util.*

class HomeCloudView : FrameLayout, IHomeContentView {

    constructor(context: Context) : super(context) {
        init(null, 0)
    }

    constructor(context: Context, attrs: AttributeSet) : super(context, attrs) {
        init(attrs, 0)
    }

    constructor(context: Context, attrs: AttributeSet, defStyle: Int) : super(context, attrs, defStyle) {
        init(attrs, defStyle)
    }

    private val ctx = ContextService
    private val sheet = Services.sheet

    private val appRepo by lazy { Repos.app }
    private val permsRepo by lazy { Repos.perms }

    private lateinit var vm: TunnelViewModel
    private lateinit var accountVM: AccountViewModel
    private lateinit var adsCounterVm: AdsCounterViewModel

    private lateinit var powerButton: PowerView

    lateinit var parentFragmentManager: FragmentManager
    lateinit var viewLifecycleOwner: LifecycleOwner
    lateinit var lifecycleScope: LifecycleCoroutineScope

    lateinit var showVpnPermsSheet: () -> Unit
    lateinit var showLocationSheet: () -> Unit
    lateinit var showPlusSheet: () -> Unit
    lateinit var showFailureDialog: (ex: BlokadaException) -> Unit
    lateinit var setHasOptionsMenu: (Boolean) -> Unit

    private fun init(attrs: AttributeSet?, defStyle: Int) {
        // Load attributes
        val a = context.obtainStyledAttributes(attrs, R.styleable.PlusButton, defStyle, 0)
        a.recycle()

        // Inflate
        LayoutInflater.from(context).inflate(R.layout.fragment_home, this, true)
        setBackgroundResource(R.drawable.bg_gradient)
    }

    fun setup() {
        val root = this
        val app = ctx.requireApp() as MainApplication
        vm = ViewModelProvider(app).get(TunnelViewModel::class.java)
        accountVM = ViewModelProvider(app).get(AccountViewModel::class.java)
        adsCounterVm = ViewModelProvider(app).get(AdsCounterViewModel::class.java)

        val plusButton: PlusButton = root.findViewById(R.id.home_plusbutton)
        powerButton = root.findViewById(R.id.home_powerview)

        var plusButtonReady = false

        val longStatus: TextView = root.findViewById(R.id.home_longstatus)
        val updateLongStatus = { appState: AppState, inProgress: Boolean, counter: Long? ->
            longStatus.text = when {
                inProgress -> context.getString(R.string.home_status_detail_progress)
//                appState == AppState.Activated && s.gatewayId != null && counter == null -> {
//                    (
//                            context.getString(R.string.home_status_detail_active) + "\n" +
//                            context.getString(R.string.home_status_detail_plus)
//                    ).withBoldSections(context.getColorFromAttr(R.attr.colorRingPlus1))
//                }
                appState == AppState.Activated && EnvironmentService.isSlim() -> {
                    context.getString(R.string.home_status_detail_active_slim)
                    .withBoldSections(context.getColorFromAttr(R.attr.colorRingLibre1))
                }
                appState == AppState.Activated && counter == null -> {
                    context.getString(R.string.home_status_detail_active)
                    .withBoldSections(context.getColorFromAttr(R.attr.colorRingLibre1))
                }
//                s.active && s.gatewayId != null -> {
//                    (
//                        context.getString(R.string.home_status_detail_active_with_counter, counter.toString()) + "\n" +
//                        context.getString(R.string.home_status_detail_plus)
//                    ).withBoldSections(context.getColorFromAttr(R.attr.colorRingPlus1))
//                }
                appState == AppState.Activated -> {
                    context.getString(R.string.home_status_detail_active_with_counter, counter.toString())
                    .withBoldSections(context.getColorFromAttr(R.attr.colorRingLibre1))
                }
                else -> context.getString(R.string.home_action_tap_to_activate)
            }

//            longStatus.setOnClickListener {
//                when {
//                    s.inProgress -> Unit
//                    s.error != null -> Unit
//                    s.active -> {
//                        val fragment = ProtectionLevelFragment.newInstance()
//                        fragment.show(parentFragmentManager, null)
//                    }
//                    !accountVM.isActive() -> {
//                        showPlusSheet()
//                    }
//                    else -> vm.turnOn()
//                }
//            }
        }

        lifecycleScope.launch {
            combine(
                appRepo.appStateHot,
                appRepo.workingHot,
                permsRepo.dnsProfilePermsHot
            ) { appState, working, dnsProfilePerms ->
                Triple(appState, working, dnsProfilePerms)
            }.collect {
                val (appState, working, dnsProfilePerms) = it

                powerButton.setOnClickListener {
                    when {
                        working -> Unit
                        !accountVM.isActive() -> {
                            sheet.showSheet(Sheet.Payment)
                        }
                        !dnsProfilePerms -> {
                            sheet.showSheet(Sheet.Activated)
                        }
                        //} else if !self.vm.vpnPermsGranted && self.vm.accountType == .Plus {
                        appState == AppState.Paused -> {
                            lifecycleScope.launch { appRepo.unpauseApp() }
                        }
                        else -> {
                            // TODO: actual date
                            lifecycleScope.launch { appRepo.pauseApp(Date()) }
                        }
                    }
                }

            }
        }

        lifecycleScope.launch {
            combine(
                appRepo.appStateHot,
                appRepo.workingHot,
            ) { appState, working -> appState to working
            }.collect {
                val (appState, inProgress) = it

                powerButton.cover = !inProgress && appState != AppState.Activated
                powerButton.loading = inProgress
                powerButton.blueMode = appState == AppState.Activated
                //powerButton.orangeMode = !s.inProgress && s.gatewayId != null
                powerButton.isEnabled = !inProgress

                val status: TextView = root.findViewById(R.id.home_status)
                status.text = when {
                    inProgress -> "..."
                    appState == AppState.Activated -> context.getString(R.string.home_status_active).toUpperCase()
                    else -> context.getString(R.string.home_status_deactivated).toUpperCase()
                }

                plusButton.visible = inProgress || appState == AppState.Activated
                plusButton.isEnabled = !inProgress
//                if (!inProgress) {
//                    // Trying to fix a weird out of sync switch state
//                    lifecycleScope.launch {
//                        plusButton.plusActive = s.isPlusMode()
//                    }
//                }

                updateLongStatus(appState, inProgress, adsCounterVm.counter.value?.let {
                    if (it == 0L) null else it
                })

                // Only after first init, to not animate on fragment creation
                powerButton.animate = true
                plusButton.animate = plusButtonReady
                plusButtonReady = true // Hacky
            }

        }

//        vm.tunnelStatus.observe(viewLifecycleOwner, Observer { s ->
//            when {
//                s.error == null -> Unit
//                s.error is NoPermissions -> showVpnPermsSheet()
//                else -> showFailureDialog(s.error)
//            }
//        })

//        adsCounterVm.counter.observe(viewLifecycleOwner, Observer { counter ->
//            vm.tunnelStatus.value?.let { s ->
//                updateLongStatus(s, counter)
//            }
//        })

//        vm.config.observe(viewLifecycleOwner, Observer { config ->
//            plusButton.location = config.gateway?.niceName()
//            plusButton.plusEnabled = config.vpnEnabled
//        })

//        plusButton.onNoLocation = showLocationSheet
//
//        plusButton.onActivated = { activated ->
//            if (activated) vm.switchGatewayOn()
//            else vm.switchGatewayOff()
//        }

//        accountVM.account.observe(viewLifecycleOwner, Observer { account ->
//            plusButton.upgrade = !account.isActive()
//            plusButton.animate = plusButtonReady
//            plusButtonReady = true // Hacky
//
//            plusButton.onClick = {
//                if (account.isActive()) showLocationSheet()
//                else showPlusSheet()
//            }
//
//            if (!account.isActive()) {
//                setHasOptionsMenu(true)
//            }
//        })
    }

    override fun onResume() {
        powerButton.start()
    }

    override fun onPause() {
        powerButton.stop()
    }

}