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
import model.*
import service.Services
import ui.PackDataSource
import ui.advanced.packs.convertBlocklists
import utils.Ignored
import utils.Logger
import utils.SimpleTasker
import utils.Tasker


class PackRepo {

    private val api = Services.apiForCurrentUser
    private val dataSource = PackDataSource

    private val cloudRepo by lazy { Repos.cloud }

    private val writeBlocklists = MutableSharedFlow<List<Blocklist>?>(replay = 1)
    private val writePacks = MutableSharedFlow<List<Pack>?>(replay = 1)

    // Blocklists is server side representation of all known lists.
    private val blocklistsHot = writeBlocklists.filterNotNull()

    // Intermediate representation, internal to this class.
    private val mappedBlocklistsHot = blocklistsHot.map { b ->
        convertBlocklists(b.filter { !it.is_allowlist })
    }

    // Used internally to access the map synchronously
    private var mappedBlocklistsInternal = emptyList<MappedBlocklist>()
        @Synchronized set
        @Synchronized get

    // Packs is app's representation. One pack may have multiple configs.
    val packsHot = writePacks.filterNotNull()

    private val loadBlocklistsT = SimpleTasker<Ignored>("loadBlocklists", errorIsMajor = true, timeoutMs = 30000)
    private val convertBlocklistsToPacksT = SimpleTasker<Ignored>("convertBlocklistsToPacks", errorIsMajor = true, timeoutMs = 30000)
    private val installPackT = Tasker<Pack, Ignored>("installPack", errorIsMajor = true, timeoutMs = 30000)
    private val uninstallPackT = Tasker<Pack, Ignored>("uninstallPack", errorIsMajor = true, timeoutMs = 30000)

    fun start() {
        onLoadBlocklists()
        onConvertBlocklistsToPacks()
        onInstallPack()
        onUninstallPack()
        onLoadBlocklists_convertBlocklistsToPacks()
        onBlocklistsIdsChanged_sync()
        onMappedBlocklistsChanged_setField()
    }

    suspend fun installPack(pack: Pack) {
        installPackT.send(pack)
    }

    suspend fun uninstallPack(pack: Pack) {
        uninstallPackT.send(pack)
    }

    // When user changes configuration (selects / deselects) for a pack that is (in)active
    suspend fun changeConfig(pack: Pack, config: PackConfig) {
        val pack = pack.changeStatus(installed = false, config = config)
        installPack(pack)
    }

    fun getPackNameForBlocklist(id: String?): String? {
        val packId = mappedBlocklistsInternal.firstOrNull { it.id == id }?.packId
        return dataSource.getPacks().firstOrNull { it.id == packId }?.meta?.title
    }

    private fun onLoadBlocklists() {
        loadBlocklistsT.setTask {
            val packs = api.getBlocklistsForCurrentUser()
            writeBlocklists.emit(packs)
            it
        }
    }

    // Converts blocklists returned by backend to internal Packs.
    // The app knows a set of Packs (defined in PackDataSource).
    // Here it checks what known packs are active in backend, and ignores the rest.
    private fun onConvertBlocklistsToPacks() {
        convertBlocklistsToPacksT.setTask {
            // Get the intermediate representation, and the backend IDs of active ones.
            val activeBlocklistIds = cloudRepo.blocklistsHot.first()
            val blocklists = mappedBlocklistsHot.first()
            val mapped = blocklists.filter { activeBlocklistIds.contains(it.id) }

            // Map those to the known packs.
            var packs = dataSource.getPacks()
            val packsDict = mutableMapOf<String, Pack>()
            packs.forEach { pack -> packsDict[pack.id] = pack }
            mapped.forEach { mapping ->
                val packId = mapping.packId
                val configName = mapping.packConfig
                val pack = packsDict[packId]

                when {
                    pack == null -> {
                        Logger.w("Pack", "reload: unknown pack id: $packId")
                    }
                    !pack.configs.contains(configName) -> {
                        Logger.w("Pack", "reload: pack $packId doesnt know config $configName")
                    }
                    else -> {
                        val newPack = pack.changeStatus(installed = true, config = configName)
                        packsDict[packId] = newPack
                        packs = packs.map { if (it.id == packId) newPack else it }
                    }
                }
            }

            writePacks.emit(packs)
            true
        }
    }

    private fun onLoadBlocklists_convertBlocklistsToPacks() {
        GlobalScope.launch {
            mappedBlocklistsHot
            .collect {
                convertBlocklistsToPacksT.send()
            }
        }
    }

    private fun onInstallPack() {
        installPackT.setTask { pack ->
            // Select default config for this pack if none selected
            var pack = pack.changeStatus(installing = true, installed = true)
            if (pack.status.config.isEmpty()) {
                Logger.v("Pack", "installPack: selecting first config by default: ${pack.configs.first()}")
                pack = pack.changeStatus(config = pack.configs.first())
            }

            // Announce this pack is installing
            var packs = packsHot.first()
            var newPacks = packs.map { if (it.id == pack.id) pack else it }
            writePacks.emit(newPacks)

            // Get the fresh blocklists information
            val activeBlocklistIds = cloudRepo.blocklistsHot.first()
            val blocklists = mappedBlocklistsHot.first()

            try {
                // Do the actual installation in the Cloud
                val mapped = blocklists.filter {
                    // Get only mapping for selected pack
                    it.packId == pack.id
                            // And only for configs that are active for this pack
                            && pack.status.config.contains(it.packConfig)
                }

                if (mapped.isEmpty()) {
                    throw BlokadaException("Could not find relevant blocklist for: ${pack.id}")
                } else {
                    Logger.v("Pack", "New choice: $mapped")
                }

                // A config might have been unselected for the currently edited pack
                val oldSelectionForThisPack = blocklists.filter { it.packId == pack.id }.map { it.id }

                // Merge lists unique (and maybe deselect a config from current pack)
                val newActiveLists = mapped.map { it.id }.toSet().union(
                    activeBlocklistIds.toSet().minus(oldSelectionForThisPack)
                ).toList()

                cloudRepo.setBlocklists(newActiveLists)

                // Announce this pack is not installing after successful install
                packs = packsHot.first()
                pack = pack.changeStatus(installed = true, updatable = false, installing = false)
                newPacks = packs.map { if(it.id == pack.id) pack else it }
                writePacks.emit(newPacks)
            } catch (ex: Exception) {
                // Announce also if failed installing
                packs = packsHot.first()
                pack = pack.changeStatus(installed = false, installing = false)
                newPacks = packs.map { if(it.id == pack.id) pack else it }
                writePacks.emit(newPacks)
                Logger.e("Packs", "Failed installing pack: ${pack.id}, err: $ex")
            }

            true
        }
    }

    private fun onUninstallPack() {
        uninstallPackT.setTask { pack ->
            // Announce this pack is uninstalling
            var packs = packsHot.first()
            var pack = pack.changeStatus(installing = true, installed = false)
            var newPacks = packs.map { if (it.id == pack.id) pack else it }
            writePacks.emit(newPacks)

            // Get the fresh blocklists information
            val activeBlocklistIds = cloudRepo.blocklistsHot.first()
            val blocklists = mappedBlocklistsHot.first()

            try {
                // Do the actual uninstallation in the Cloud
                val mapped = blocklists.filter {
                    // Get only mapping for selected pack
                    it.packId == pack.id
                }

                if (mapped.isEmpty()) {
                    throw BlokadaException("Could not find relevant blocklist for: ${pack.id}")
                }

                // Merge lists unique
                val newActiveLists = activeBlocklistIds.toSet().minus(mapped.map { it.id }).toList()

                cloudRepo.setBlocklists(newActiveLists)

                // Announce this pack is not uninstalling after successful install
                packs = packsHot.first()
                pack = pack.changeStatus(installed = false, updatable = false, installing = false)
                newPacks = packs.map { if(it.id == pack.id) pack else it }
                writePacks.emit(newPacks)
            } catch (ex: Exception) {
                // Announce also if failed uninstalling
                packs = packsHot.first()
                pack = pack.changeStatus(installed = true, installing = false)
                newPacks = packs.map { if(it.id == pack.id) pack else it }
                writePacks.emit(newPacks)
                Logger.e("Packs", "Failed installing pack: ${pack.id}, err: $ex")
            }
            true
        }
    }

    private fun onBlocklistsIdsChanged_sync() {
        GlobalScope.launch {
            cloudRepo.blocklistsHot
            .collect {
                loadBlocklistsT.send()
            }
        }
    }

    private fun onMappedBlocklistsChanged_setField() {
        GlobalScope.launch {
            mappedBlocklistsHot.collect { mappedBlocklistsInternal = it }
        }
    }

}