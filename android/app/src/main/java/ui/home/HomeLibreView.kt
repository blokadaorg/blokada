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
import android.widget.Toast
import androidx.fragment.app.FragmentManager
import androidx.lifecycle.LifecycleCoroutineScope
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import kotlinx.coroutines.launch
import model.AccountType
import model.BlokadaException
import model.NoPermissions
import model.TunnelStatus
import org.blokada.R
import service.ContextService
import service.EnvironmentService
import ui.AccountViewModel
import ui.AdsCounterViewModel
import ui.MainApplication
import ui.TunnelViewModel
import ui.utils.getColorFromAttr
import utils.withBoldSections

interface IHomeContentView {
    fun onResume()
    fun onPause()
}

class HomeLibreView : FrameLayout, IHomeContentView {

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

        val status: TextView = root.findViewById(R.id.home_status)
        status.text = context.getString(R.string.home_status_deactivated).toUpperCase()

        val longStatus: TextView = root.findViewById(R.id.home_longstatus)
        val updateLongStatus = { s: TunnelStatus, counter: Long? ->
            longStatus.text = when {
                s.inProgress -> context.getString(R.string.home_status_detail_progress)
                s.active && s.gatewayId != null && counter == null -> {
                    (
                            context.getString(R.string.home_status_detail_active) + "\n" +
                                    context.getString(R.string.home_status_detail_plus)
                            ).withBoldSections(context.getColorFromAttr(R.attr.colorRingPlus1))
                }
                s.active && EnvironmentService.isSlim() -> {
                    context.getString(R.string.home_status_detail_active_slim)
                        .withBoldSections(context.getColorFromAttr(R.attr.colorRingLibre1))
                }
                s.active && counter == null -> {
                    context.getString(R.string.home_status_detail_active)
                        .withBoldSections(context.getColorFromAttr(R.attr.colorRingLibre1))
                }
                s.active && s.gatewayId != null -> {
                    (
                            context.getString(R.string.home_status_detail_active_with_counter, counter.toString()) + "\n" +
                                    context.getString(R.string.home_status_detail_plus)
                            ).withBoldSections(context.getColorFromAttr(R.attr.colorRingPlus1))
                }
                s.active -> {
                    context.getString(R.string.home_status_detail_active_with_counter, counter.toString())
                        .withBoldSections(context.getColorFromAttr(R.attr.colorRingLibre1))
                }
                else -> context.getString(R.string.home_action_tap_to_activate)
            }

            longStatus.setOnClickListener {
                when {
                    s.inProgress -> Unit
                    s.error != null -> Unit
                    s.active -> {
                        val fragment = ProtectionLevelFragment.newInstance()
                        fragment.show(parentFragmentManager, null)
                    }
                    else -> vm.turnOn()
                }
            }
        }

        vm.tunnelStatus.observe(viewLifecycleOwner, Observer { s ->
            powerButton.cover = !s.inProgress && !s.active
            powerButton.loading = s.inProgress
            powerButton.blueMode = s.active
            powerButton.orangeMode = !s.inProgress && s.gatewayId != null
            powerButton.isEnabled = !s.inProgress

            powerButton.setOnClickListener {
                when {
                    s.inProgress -> Unit
                    s.error != null -> Unit
                    EnvironmentService.isSlim() -> {
                        // The slim build will not let to start the app (if not escaped).
                        // This is because the slim build got banned by Google and this is the attempt
                        // to migrate users that still have slim installed.
                        Toast.makeText(context, "Could not activate. Search 'Blokada 6' on Google Play to update.", Toast.LENGTH_LONG).show()
                    }
                    s.active -> {
                        vm.turnOff()
                        adsCounterVm.roll()
                    }
                    else -> vm.turnOn()
                }
            }

            val status: TextView = root.findViewById(R.id.home_status)
            status.text = when {
                s.inProgress -> "..."
                s.active -> context.getString(R.string.home_status_active).toUpperCase()
                else -> context.getString(R.string.home_status_deactivated).toUpperCase()
            }

            updateLongStatus(s, adsCounterVm.counter.value?.let {
                if (it == 0L) null else it
            })

            when {
                s.error == null -> Unit
                s.error is NoPermissions -> showVpnPermsSheet()
                else -> showFailureDialog(s.error)
            }

            plusButton.visible = s.active && accountVM.account.value?.getType() != AccountType.Cloud
            plusButton.isEnabled = !s.inProgress
            if (!s.inProgress) {
                // Trying to fix a weird out of sync switch state
                lifecycleScope.launch {
                    plusButton.plusActive = s.isPlusMode()
                }
            }

            // Only after first init, to not animate on fragment creation
            powerButton.animate = true
            plusButton.animate = plusButtonReady
            plusButtonReady = true // Hacky
        })

        adsCounterVm.counter.observe(viewLifecycleOwner, Observer { counter ->
            vm.tunnelStatus.value?.let { s ->
                updateLongStatus(s, counter)
            }
        })

        vm.config.observe(viewLifecycleOwner, Observer { config ->
            plusButton.location = config.gateway?.niceName()
            plusButton.plusEnabled = config.vpnEnabled
        })

        plusButton.onNoLocation = showLocationSheet

        plusButton.onActivated = { activated ->
            if (activated) vm.switchGatewayOn()
            else vm.switchGatewayOff()
        }

        accountVM.account.observe(viewLifecycleOwner, Observer { account ->
            plusButton.visible = accountVM.account.value?.getType() != AccountType.Cloud
            plusButton.upgrade = account.getType() != AccountType.Plus
            plusButton.animate = plusButtonReady
            plusButtonReady = true // Hacky

            plusButton.onClick = {
                if (account.getType() == AccountType.Plus) showLocationSheet()
                else showPlusSheet()
            }

            if (!account.isActive()) {
                setHasOptionsMenu(true)
            }
        })
    }

    override fun onResume() {
        powerButton.start()
    }

    override fun onPause() {
        powerButton.stop()
    }

}