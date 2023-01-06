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

package engine

import service.PrintsDebugInfo
import utils.FlavorSpecific
import utils.Logger

internal object FilteringService: PrintsDebugInfo, FlavorSpecific {

    fun reload() {
        Logger.v("Filtering", "Using no filtering")
    }

    fun allowed(host: Host): Boolean {
        return true
    }

    fun denied(host: Host): Boolean {
        return false
    }

    override fun printDebugInfo() {
    }

}

typealias Host = String