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
import model.BlokadaException
import ui.home.ActivatedFragment
import ui.home.CloudPaymentFragment
import ui.home.OnboardingFragment
import ui.home.PaymentFragment

enum class Sheet {
    Help, // Help Screen (contact us)
    Payment, // Main payment screen with plans
    Location, // Location selection screen for Blokada Plus
    Activated, // A welcome showing right after purchase
    ShowLog, // Shows log with a possibliity to share
    ShareLog, // Opens OS'es file sharing with the log attached
    Debug, // Debug shortcuts and actions, not accessible in production builds
    RateApp, // Asking user to put a review
    AdsCounter, // A big total ads blocked display with option no share
    ShareAdsCounter // Opens OS'es sharing with a short message with blocked counter
}

class SheetService {

    fun showSheet(sheet: Sheet) {
        val fragment = when (sheet) {
            Sheet.Payment -> CloudPaymentFragment.newInstance()
            Sheet.Activated -> OnboardingFragment.newInstance()
            else -> throw BlokadaException("unsupported sheet")
        }
        onShowFragment(fragment)
    }

    var onShowFragment: (DialogFragment) -> Unit = { }

}