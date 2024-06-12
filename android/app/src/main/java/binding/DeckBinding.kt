/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2023 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import channel.command.CommandName
import channel.filter.Filter
import channel.filter.FilterOps
import kotlinx.coroutines.flow.MutableStateFlow
import service.FlutterService
import ui.advanced.decks.PackDataSource

object DeckBinding: FilterOps {
    val filters = MutableStateFlow<List<Filter>>(emptyList())
    val selections = MutableStateFlow<List<Filter>>(emptyList())
    val listToTags = MutableStateFlow<Map<String, String>>(emptyMap())

    private val dataSource = PackDataSource.getPacks()

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }

    init {
        FilterOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    private fun getDeckIdForList(listId: String): String? {
        return listToTags.value[listId]?.split("/")?.firstOrNull();
    }

    fun getDeckNameForList(listId: String): String? {
        val deckId = getDeckIdForList(listId) ?: return null
        return dataSource.firstOrNull { it.id == deckId }?.meta?.title
    }

    suspend fun setDeckEnabled(deckId: String, enabled: Boolean) {
        if (enabled) {
            command.execute(CommandName.ENABLEDECK, deckId)
        } else {
            command.execute(CommandName.DISABLEDECK, deckId)
        }
    }

    suspend fun toggleListEnabledForTag(deckId: String, tag: String) {
        command.execute(CommandName.TOGGLELISTBYTAG, deckId, tag)
    }

    override fun doFiltersChanged(filters: List<Filter>, callback: (Result<Unit>) -> Unit) {
        this.filters.value = filters
        callback(Result.success(Unit))
    }

    override fun doFilterSelectionChanged(
        selections: List<Filter>,
        callback: (Result<Unit>) -> Unit
    ) {
        this.selections.value = selections
        callback(Result.success(Unit))
    }

    override fun doListToTagChanged(
        listToTag: Map<String, String>,
        callback: (Result<Unit>) -> Unit
    ) {
        callback(Result.success(Unit))
    }
}