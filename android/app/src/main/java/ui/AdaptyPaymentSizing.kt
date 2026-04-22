/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2026 Blocka AB. All rights reserved.
 */

package ui

import android.content.Context
import kotlin.math.min

private const val TABLET_PAYWALL_BREAKPOINT_DP = 720
private const val TABLET_PAYWALL_MAX_WIDTH_DP = 600
private const val TABLET_PAYWALL_SIDE_MARGIN_DP = 24
private const val TABLET_PAYWALL_HEIGHT_RATIO = 0.9f

fun Context.shouldUseCenteredAdaptyPaywall(): Boolean =
    resources.configuration.screenWidthDp >= TABLET_PAYWALL_BREAKPOINT_DP

fun Context.centeredAdaptyPaywallWidthPx(): Int {
    val density = resources.displayMetrics.density
    val maxWidthPx = (TABLET_PAYWALL_MAX_WIDTH_DP * density).toInt()
    val marginPx = (TABLET_PAYWALL_SIDE_MARGIN_DP * density).toInt()
    val screenWidthPx = resources.displayMetrics.widthPixels
    return min(maxWidthPx, screenWidthPx - (marginPx * 2))
}

fun Context.centeredAdaptyPaywallHeightPx(): Int =
    (resources.displayMetrics.heightPixels * TABLET_PAYWALL_HEIGHT_RATIO).toInt()
