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
import ui.home.FamilyPaymentFragment
import ui.home.LocationFragment
import ui.home.ScanQrFragment

enum class Sheet {
    Help, // Help Screen (contact us)
    Payment, // Main payment screen with plans
    Location, // Location selection screen for Blokada Plus
    Activated, // A welcome showing right after purchase
    ConnIssues, // A detail view when tapping the connection issues overlay
    Custom, // Displays user defined custom exceptions lists
    AccountChange, // Displays the scan QR code screen
}

object SheetService {
    private val stage by lazy { StageBinding }

    private var fragment: DialogFragment? = null

    fun showSheet(sheet: Sheet) {
        val fragment = when (sheet) {
            Sheet.Payment -> {
                if (Flavor.isFamily())
                    FamilyPaymentFragment.newInstance()
                else
                    CloudPaymentFragment.newInstance()
            }
            Sheet.Location -> LocationFragment.newInstance()
            Sheet.AccountChange -> ScanQrFragment.newInstance()
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
        } ?: stage.modalDismissed()
    }

    fun sheetDismissed() {
        if (fragment == null) return
        fragment = null
        stage.modalDismissed()
    }

    var onShowFragment: (DialogFragment) -> Unit = { }
    var onHideFragment: (DialogFragment) -> Unit = { }
}