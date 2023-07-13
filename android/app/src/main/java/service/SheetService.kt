/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import androidx.fragment.app.DialogFragment
import binding.StageBinding
import model.BlokadaException
import ui.home.CloudPaymentFragment
import ui.home.ConnIssuesFragment
import ui.home.HelpFragment
import ui.home.LocationFragment
import ui.home.OnboardingFragment
import ui.journal.custom.UserDeniedFragment

enum class Sheet {
    Help, // Help Screen (contact us)
    Payment, // Main payment screen with plans
    Location, // Location selection screen for Blokada Plus
    Activated, // A welcome showing right after purchase
    AdsCounter, // A big total ads blocked display with option no share
    ConnIssues, // A detail view when tapping the connection issues overlay
    Custom // Displays user defined custom exceptions lists
}

object SheetService {
    private val stage by lazy { StageBinding }

    private var fragment: DialogFragment? = null

    fun showSheet(sheet: Sheet) {
        val fragment = when (sheet) {
            Sheet.Payment -> CloudPaymentFragment.newInstance()
            Sheet.Activated -> OnboardingFragment.newInstance()
            Sheet.ConnIssues -> ConnIssuesFragment.newInstance()
            Sheet.Location -> LocationFragment.newInstance()
            Sheet.Help -> HelpFragment.newInstance()
            Sheet.Custom -> UserDeniedFragment.newInstance()
            else -> throw BlokadaException("unsupported sheet")
        }
        this.fragment = fragment
        onShowFragment(fragment)
    }

    fun dismiss() {
        fragment?.run {
            onHideFragment(this)
            fragment = null
            stage.modalDismissed()
        } ?: sheetDismissed()
    }

    fun sheetDismissed() {
        if (fragment == null) return
        fragment = null
        stage.modalDismissed()
    }

    var onShowFragment: (DialogFragment) -> Unit = { }
    var onHideFragment: (DialogFragment) -> Unit = { }
}