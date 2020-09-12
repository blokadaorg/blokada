/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui

import androidx.lifecycle.*
import kotlinx.coroutines.launch
import model.*
import repository.BlockaRepoRepository
import service.AlertDialogService
import service.EnvironmentService
import service.PersistenceService
import ui.utils.cause
import ui.utils.now
import utils.Logger

class BlockaRepoViewModel: ViewModel() {

    private val log = Logger("BlockaRepo")
    private val repository = BlockaRepoRepository
    private val env = EnvironmentService
    private val persistence = PersistenceService

    private val _repoConfig = MutableLiveData<BlockaRepoConfig>()
    val repoConfig: LiveData<BlockaRepoConfig> = _repoConfig.distinctUntilChanged()

    fun maybeRefreshRepo() {
        viewModelScope.launch {
            try {
                val config = persistence.load(BlockaRepoConfig::class)
                if (now() > config.lastRefresh + REPO_REFRESH_MILLIS) {
                    log.w("Repo config is stale, refreshing")
                    refreshRepo()
                } else {
                    _repoConfig.value = config
                }
            } catch (ex: Exception) {
                log.w("Could not load repo config, ignoring".cause(ex))
            }
        }
    }

    fun refreshRepo() {
        viewModelScope.launch {
            try {
                val config = processConfig(repository.fetch()).copy(
                    lastRefresh = now()
                )
                _repoConfig.value = config
                persistence.save(config)
            } catch (ex: Exception) {
                log.w("Could not refresh repo, ignoring".cause(ex))
            }
        }
    }

    private fun applyConfig(repo: BlockaRepo): BlockaRepoConfig {
        val config = processConfig(repo)
        log.v("cfg: $config")
        return config
    }

    private fun processConfig(repo: BlockaRepo): BlockaRepoConfig {
        log.v("Processing config")
        val common = repo.common
        val mine = repo.buildConfigs.firstOrNull { it.forBuild == env.getBuildName() }
        return if (mine == null) {
            log.w("No build config matched, using only common config")
            common
        } else {
            log.v("Using config: ${mine.name}")
            return mine.combine(common)
        }
    }

}

private const val REPO_REFRESH_MILLIS = 12 * 60 * 60 * 1000