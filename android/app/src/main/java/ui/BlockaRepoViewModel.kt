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

package ui

import androidx.lifecycle.*
import kotlinx.coroutines.launch
import model.BlockaRepo
import model.BlockaRepoConfig
import repository.BlockaRepoRepository
import service.EnvironmentService
import service.PersistenceService
import ui.utils.cause
import ui.utils.now
import utils.Logger

private const val REPO_REFRESH_MILLIS = 12 * 60 * 60 * 1000