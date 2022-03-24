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

import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.distinctUntilChanged
import kotlinx.coroutines.flow.*
import model.Account
import model.AppStage
import utils.Logger

class StageRepo {

    private val writeStage = MutableStateFlow<AppStage?>(null)

    var stageHot = writeStage.filterNotNull().distinctUntilChanged()

    var enteredForegroundHot = writeStage
        .filter { it == AppStage.Foreground }
        .debounce(1)
        .map { true }

    var creatingHot = writeStage
        .filter { it == AppStage.Creating }
        .debounce(1)
        .map { true }

    var destroyingHot = writeStage
        .filter { it == AppStage.Destroying }
        .debounce(1)
        .map { true }

    fun start() {
        onCreate()
    }

    private fun onCreate() {
        writeStage.value = AppStage.Creating
    }

    fun onForeground() {
        writeStage.value = AppStage.Foreground
    }

    fun onBackground() {
        writeStage.value = AppStage.Background
    }

    fun onDestroy() {
        writeStage.value = AppStage.Destroying
    }

}