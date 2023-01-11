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
import android.widget.FrameLayout
import android.widget.TextView
import androidx.fragment.app.FragmentManager
import androidx.lifecycle.LifecycleCoroutineScope
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModelProvider
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import model.AccountType
import model.AppState
import model.BlokadaException
import model.NoPermissions
import org.blokada.R
import repository.Repos
import service.ContextService
import service.Services
import service.Sheet
import ui.AccountViewModel
import ui.MainApplication
import ui.TunnelViewModel
import ui.utils.getColorFromAttr
import utils.withBoldSections
import java.util.*

class HomeCloudView : FrameLayout {

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
    private val plusRepo by lazy { Repos.plus }
    private val permsRepo by lazy { Repos.perms }
    private val statsRepo by lazy { Repos.stats }

    private lateinit var vm: TunnelViewModel
    private lateinit var accountVM: AccountViewModel

    private lateinit var powerButton: PowerView

    lateinit var parentFragmentManager: FragmentManager
    lateinit var viewLifecycleOwner: LifecycleOwner
    lateinit var lifecycleScope: LifecycleCoroutineScope

    lateinit var showLocationSheet: () -> Unit
    lateinit var showPlusSheet: () -> Unit
    lateinit var showFailureDialog: (ex: BlokadaException) -> Unit
    lateinit var setHasOptionsMenu: (Boolean) -> Unit

    private fun init(attrs: AttributeSet?, defStyle: Int) {
        // Load attributes
        val a = context.obtainStyledAttributes(attrs, R.styleable.CloudView, defStyle, 0)
        a.recycle()

        // Inflate
        LayoutInflater.from(context).inflate(R.layout.fragment_home, this, true)
        setBackgroundResource(R.drawable.bg_home_off)
    }

    fun setup() {
        val root = this
        val app = ctx.requireApp() as MainApplication
        vm = ViewModelProvider(app).get(TunnelViewModel::class.java)
        accountVM = ViewModelProvider(app).get(AccountViewModel::class.java)

        val plusButton: PlusButton = root.findViewById(R.id.home_plusbutton)
        powerButton = root.findViewById(R.id.home_powerview)

        // This listener is only for when the app did not initiate because of lack of connectivity
        // at start (eg airplane mode). The app will recover as soon as there is connectivity,
        // and this listener is going to be overwritten below.
        powerButton.setOnClickListener {
            showFailureDialog(BlokadaException("Device is probably offline"))
        }

        var plusButtonReady = false

        val status: TextView = root.findViewById(R.id.home_status)
        status.text = context.getString(R.string.home_status_deactivated).toUpperCase()

        val longStatus: TextView = root.findViewById(R.id.home_longstatus)
        val updateLongStatus = { appState: AppState, inProgress: Boolean, plusEnabled: Boolean, counter: Long? ->
            longStatus.text = when {
                inProgress -> context.getString(R.string.home_status_detail_progress)
                appState == AppState.Activated && plusEnabled && counter == null -> {
                    (
                            context.getString(R.string.home_status_detail_active) + "\n" +
                            context.getString(R.string.home_status_detail_plus)
                    ).withBoldSections(context.getColorFromAttr(R.attr.colorRingPlus1))
                }
                appState == AppState.Activated && counter == null -> {
                    context.getString(R.string.home_status_detail_active)
                    .withBoldSections(context.getColorFromAttr(R.attr.colorRingLibre1))
                }
                appState == AppState.Activated && plusEnabled -> {
                    (
                        context.getString(R.string.home_status_detail_active_with_counter, counter.toString()) + "\n" +
                        context.getString(R.string.home_status_detail_plus)
                    ).withBoldSections(context.getColorFromAttr(R.attr.colorRingPlus1))
                }
                appState == AppState.Activated -> {
                    context.getString(R.string.home_status_detail_active_with_counter, counter.toString())
                    .withBoldSections(context.getColorFromAttr(R.attr.colorRingLibre1))
                }
                else -> context.getString(R.string.home_action_tap_to_activate)
            }

            longStatus.setOnClickListener {
                when {
                    inProgress -> Unit
                    appState == AppState.Activated -> {
                        sheet.showSheet(Sheet.AdsCounter)
                    }
                    !accountVM.isActive() -> {
                        showPlusSheet()
                    }
                    else -> vm.turnOn()
                }
            }
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
                        appState == AppState.Paused -> {
                            powerButton.loading = true
                            powerButton.cover = false
                            lifecycleScope.launch { appRepo.unpauseApp() }
                        }
                        else -> {
                            powerButton.loading = true
                            //powerButton.cover = false
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
                statsRepo.blockedHot,
                plusRepo.plusEnabled
            ) { a, b, c, d -> listOf(a, b, c, d)
            }.collect {
                val (appState, inProgress, blocked, plusEnabled) = it
                appState as AppState
                inProgress as Boolean
                blocked as Long
                plusEnabled as Boolean

                powerButton.cover = !inProgress && appState != AppState.Activated
                powerButton.loading = inProgress
                powerButton.blueMode = !inProgress && appState == AppState.Activated
                powerButton.orangeMode = !inProgress && plusEnabled && appState == AppState.Activated
                powerButton.isEnabled = !inProgress

                val status: TextView = root.findViewById(R.id.home_status)
                status.text = when {
                    inProgress -> "..."
                    appState == AppState.Activated -> context.getString(R.string.home_status_active).toUpperCase()
                    else -> context.getString(R.string.home_status_deactivated).toUpperCase()
                }

                val accType = accountVM.account.value?.getType()
                val accSource = accountVM.account.value?.getSource()
                plusButton.visible = when {
                    inProgress -> false
                    appState != AppState.Activated -> false
                    accType == AccountType.Cloud && accSource != "google" -> false
                    else -> true
                }

                plusButton.isEnabled = !inProgress
                if (!inProgress) {
                    // Trying to fix a weird out of sync switch state
                    lifecycleScope.launch {
                        plusButton.plusActive = plusEnabled
                    }
                }

                updateLongStatus(appState, inProgress, plusEnabled, blocked.let {
                    if (it == 0L) null else it
                })

                // Update gradient bg
                when {
                    inProgress -> setBackgroundResource(R.drawable.bg_home_off)
                    appState != AppState.Activated -> setBackgroundResource(R.drawable.bg_home_off)
                    plusEnabled -> setBackgroundResource(R.drawable.bg_home_plus)
                    else -> setBackgroundResource(R.drawable.bg_home_cloud)
                }

                // Only after first init, to not animate on fragment creation
                powerButton.animate = true
                plusButton.animate = plusButtonReady
                plusButtonReady = true // Hacky
            }

        }

        vm.tunnelStatus.observe(viewLifecycleOwner) { s ->
            when {
                s.error == null -> Unit
                s.error is NoPermissions -> sheet.showSheet(Sheet.Activated)
                else -> showFailureDialog(s.error)
            }
        }

//        adsCounterVm.counter.observe(viewLifecycleOwner, Observer { counter ->
//            vm.tunnelStatus.value?.let { s ->
//                updateLongStatus(s, counter)
//            }
//        })

        vm.config.observe(viewLifecycleOwner) { config ->
            plusButton.location = config.gateway?.niceName()
            //plusButton.plusEnabled = config.vpnEnabled
        }

        plusButton.onNoLocation = showLocationSheet

        plusButton.onActivated = { activated ->
            lifecycleScope.launch {
                val granted = permsRepo.vpnProfilePermsHot.first()
                when {
                    !granted -> {
                        sheet.showSheet(Sheet.Activated)
                        plusButton.isActivated = !activated
                    }
                    activated -> {
                        vm.turnOn(vpnEnabled = true)
                    }
                    else -> {
                        vm.turnOff(vpnEnabled = false)
                    }
                }
            }
        }

        accountVM.account.observe(viewLifecycleOwner) { account ->
            plusButton.upgrade = account.getType() != AccountType.Plus
            plusButton.animate = plusButtonReady
            plusButtonReady = true // Hacky

            plusButton.onClick = {
                lifecycleScope.launch {
                    val granted = permsRepo.vpnProfilePermsHot.first()
                    when {
                        account.getType() != AccountType.Plus -> sheet.showSheet(Sheet.Payment)
                        !granted -> sheet.showSheet(Sheet.Activated)
                        else -> showLocationSheet()
                    }
                }
            }

//            if (!account.isActive()) {
//                setHasOptionsMenu(true)
//            }
        }
    }

    fun onResume() {
        powerButton.start()
    }

    fun onPause() {
        powerButton.stop()
    }

}