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

package ui.advanced.packs

import androidx.lifecycle.*
import kotlinx.coroutines.launch
import model.*
import service.AlertDialogService
import service.BlocklistService
import engine.EngineService
import kotlinx.coroutines.delay
import service.PersistenceService
import ui.utils.cause
import utils.Logger
import java.lang.Exception
import org.blokada.R
import ui.utils.now
import kotlin.random.Random

class PacksViewModel : ViewModel() {

    enum class Filter {
        HIGHLIGHTS, ACTIVE, ALL
    }

    private val log = Logger("Pack")
    private val persistence = PersistenceService
    private val engine = EngineService
    private val blocklist = BlocklistService
    private val alert = AlertDialogService

    private val activeTags = listOf("official")
    private var filter = Filter.HIGHLIGHTS

    private val _packs = MutableLiveData<Packs>()
    val packs = _packs.map { applyFilters(it.packs) }

    init {
        viewModelScope.launch {
            _packs.value = persistence.load(Packs::class)
        }
    }

    suspend fun setup() {
        viewModelScope.launch {
            delay(3000) // Let the app start up and not block our download
            // Refresh every 2-3 days but only on app fresh start
            if (_packs.value?.lastRefreshMillis ?: 0 < (now() - (2 * 86400 + Random.nextInt(86400)))) {
                try {
                    log.w("Packs are stale, re-downloading")
                    // Also include urls of any active pack
                    _packs.value?.let { packs ->
                        val urls = packs.packs.filter { it.status.installed }.flatMap { it.getUrls() }.distinct()
                        blocklist.downloadAll(urls, force = true)
                        blocklist.mergeAll(urls)
                        engine.reloadBlockLists()
                        persistence.save(packs.copy(lastRefreshMillis = now()))
                    }
                } catch (ex: Throwable) {
                    log.e("Could not re-download packs".cause(ex))
                }
            }
        }.join()
    }

    fun get(packId: String): Pack? {
        return _packs.value?.packs?.firstOrNull { it.id == packId }
    }

    fun filter(filter: Filter) {
        this.filter = filter
        updateLiveData()
    }

    fun getFilter() = filter

    fun changeConfig(pack: Pack, config: PackConfig) {
        val updated = pack.changeStatus(installed = false, config = config)
        updatePack(updated)
        install(updated)
    }

    fun install(pack: Pack) {
        viewModelScope.launch {
            updatePack(pack.changeStatus(installing = true, installed = true))
            try {
                var urls = pack.getUrls()

                // Also include urls of any active pack
                _packs.value?.let { packs ->
                    val moreUrls = packs.packs.filter { it.status.installed }.flatMap { it.getUrls() }
                    urls = (urls + moreUrls).distinct()
                }

                blocklist.downloadAll(urls)
                blocklist.mergeAll(urls)
                engine.reloadBlockLists()
                updatePack(pack.changeStatus(installing = false, installed = true))
            } catch (ex: Throwable) {
                log.e("Could not install pack".cause(ex))
                updatePack(pack.changeStatus(installing = false, installed = false))
                alert.showAlert(R.string.error_pack_install)
            }
        }
    }

    fun uninstall(pack: Pack) {
        viewModelScope.launch {
            updatePack(pack.changeStatus(installing = true, installed = false))
            try {
                // Uninstall any downloaded sources for this pack
                // We get all possible sources because user might have changed config and only then decided to uninstall
                val urls = pack.sources.flatMap { it.urls }
                blocklist.removeAll(urls)

                // Include urls of any active pack
                _packs.value?.let { packs ->
                    val urls = packs.packs.filter { it.status.installed && it.id != pack.id }
                        .flatMap { it.getUrls() }
                    blocklist.downloadAll(urls)
                    blocklist.mergeAll(urls)
                }

                engine.reloadBlockLists()
                updatePack(pack.changeStatus(installing = false, installed = false))
            } catch (ex: Throwable) {
                log.e("Could not uninstall pack".cause(ex))
                updatePack(pack.changeStatus(installing = false, installed = false))
                alert.showAlert(R.string.error_pack_install)
            }
        }
    }

    private fun updatePack(pack: Pack) {
        viewModelScope.launch {
            _packs.value?.let { current ->
                val new = current.replace(pack)
                persistence.save(new)
                _packs.value = new
            }
        }
    }

    private fun updateLiveData() {
        viewModelScope.launch {
            // This will cause to emit new event and to refresh the public LiveData
            _packs.value = _packs.value
        }
    }

    private fun applyFilters(allPacks: List<Pack>): List<Pack> {
        return when (filter) {
            Filter.ACTIVE -> {
                allPacks.filter { pack ->
                    pack.status.installed
                }
            }
            Filter.ALL -> {
                allPacks.filter { pack ->
                    activeTags.intersect(pack.tags).isEmpty() != true
                }
            }
            else -> {
                allPacks.filter { pack ->
                    pack.tags.contains(Pack.recommended) /* && !pack.status.installed */
                }
            }
        }
    }

}
