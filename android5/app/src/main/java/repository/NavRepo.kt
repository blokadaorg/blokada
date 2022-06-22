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

package repository

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import model.Tab

class NavRepo {

    private val writeActiveTab = MutableStateFlow<Tab?>(null)

    private val enteredForegroundHot by lazy { Repos.stage.enteredForegroundHot }

    val activeTabHot = writeActiveTab.filterNotNull().distinctUntilChanged()

    fun start() {
        onForeground_RepublishActiveTab()
    }

    suspend fun setActiveTab(tab: Tab) {
        writeActiveTab.emit(tab)
        // This is how we navigate back from multi level navigation
//        writeSectionHot.send(nil)
    }

//    func setSection(_ section: Any?) {
//        writeSectionHot.send(section)
//    }

    fun onForeground_RepublishActiveTab() {
        GlobalScope.launch {
            enteredForegroundHot
            .map { activeTabHot.first() }
            .collect {
                writeActiveTab.emit(it)
            }
        }
    }

}