/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2024 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import channel.command.CommandName
import channel.filter.Filter
import channel.filter.FilterOps
import kotlinx.coroutines.flow.MutableStateFlow
import model.Pack
import model.PackStatus
import service.FlutterService
import ui.advanced.decks.PackDataSource

object FilterBinding: FilterOps {
    val filters = MutableStateFlow<List<Filter>>(emptyList())
    val selections = MutableStateFlow<List<Filter>>(emptyList())
    val filtersAndSelections = MutableStateFlow<Pair<List<Filter>, List<Filter>>>(emptyList<Filter>() to emptyList())
    var listsToTags: MutableMap<String, String> = mutableMapOf()

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }

    private val dataSource = PackDataSource.getPacks()

    init {
        FilterOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

//    fun getDeckIdForList(listId: String): String? {
//        return DeckBinding.decks.value.firstOrNull {
//            it.items.keys.contains(listId)
//        }?.deckId
//    }
//    // TODO: remove the Pack model

    fun convertDeckToPack(filter: Filter): Pack? {
        val data = dataSource.firstOrNull { it.id == filter.filterName } ?: return null
        val selection = selections.value.firstOrNull { it.filterName == filter.filterName && it.options.isNotEmpty() }
        return Pack(
            id = filter.filterName,
            tags = data.tags,
            sources = data.sources,
            meta = data.meta,
            configs = data.configs.map { it.capitalize() },
            status = PackStatus(
                installed = selection != null,
                updatable = false,
                installing = false,
                badge = false,
                config = selection?.options?.mapNotNull { it?.capitalize() } ?: emptyList(),
                hits = 0
            ),
        )
    }

    suspend fun enableFilter(filterName: String, enabled: Boolean) {
        if (enabled) {
            command.execute(CommandName.ENABLEDECK, filterName)
        } else {
            command.execute(CommandName.DISABLEDECK, filterName)
        }
    }

    suspend fun toggleFilterOption(filterName: String, optionName: String) {
        command.execute(CommandName.TOGGLELISTBYTAG, filterName, optionName)
    }

    override fun doFiltersChanged(filters: List<Filter>, callback: (Result<Unit>) -> Unit) {
        this.filters.value = filters
        this.filtersAndSelections.value = filters to selections.value
        callback(Result.success(Unit))
    }

    override fun doFilterSelectionChanged(
        selections: List<Filter>,
        callback: (Result<Unit>) -> Unit
    ) {
        this.selections.value = selections
        this.filtersAndSelections.value = filters.value to selections
        callback(Result.success(Unit))
    }

    override fun doListToTagChanged(
        listToTag: Map<String, String>,
        callback: (Result<Unit>) -> Unit
    ) {
        this.listsToTags = listToTag.toMutableMap()
        callback(Result.success(Unit))
    }
}