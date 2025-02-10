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

package service

import model.Uri
import utils.FlavorSpecific
import utils.Logger

object BlocklistService: FlavorSpecific {

    const val MERGED_BLOCKLIST = "merged_blocklist"
    const val USER_ALLOWED = "allowed"
    const val USER_DENIED = "denied"

    suspend fun setup() {
        Logger.v("Blocklist", "Using no BlocklistService")
    }

    suspend fun downloadAll(urls: List<Uri>, force: Boolean = false) {}
    suspend fun mergeAll(urls: List<Uri>) {}
    fun removeAll(urls: List<Uri>) {}

    fun loadMerged(): List<String> {
        return emptyList()
    }

    fun loadUserAllowed(): List<String> {
        return emptyList()
    }

    fun loadUserDenied(): List<String> {
        return emptyList()
    }

}