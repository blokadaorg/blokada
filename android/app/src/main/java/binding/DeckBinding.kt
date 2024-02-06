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
import channel.deck.Deck
import channel.deck.DeckOps
import kotlinx.coroutines.flow.MutableStateFlow
import service.FlutterService
import ui.advanced.decks.PackDataSource

object DeckBinding: DeckOps {
    val decks = MutableStateFlow<List<Deck>>(emptyList())

    private val dataSource = PackDataSource.getPacks()

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }

    init {
        DeckOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    fun getDeckIdForList(listId: String): String? {
        return decks.value.firstOrNull {
            it.items.keys.contains(listId)
        }?.deckId
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

    override fun doDecksChanged(decks: List<Deck>, callback: (Result<Unit>) -> Unit) {
        this.decks.value = decks
        callback(Result.success(Unit))
    }

    override fun doTagMappingChanged(
        tapMapping: Map<String, String>,
        callback: (Result<Unit>) -> Unit
    ) {
        // TODO: not used yet on android
        callback(Result.success(Unit))
    }
}