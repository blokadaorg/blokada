//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory

class DeckBinding: DeckOps {
    
    var decks: [Deck] = []
    var tapMapping: [String: String] = [:]
    var onDecks: ([Deck]) -> Void = { _ in }

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    init() {
        DeckOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func getTagForListId(_ listId: String) -> String? {
        return tapMapping[listId]
    }

    func setDeckEnabled(deckId: String, enabled: Bool) {
        if enabled {
            commands.execute(.enableDeck, deckId)
        } else {
            commands.execute(.disableDeck, deckId)
        }
    }
    
    func toggleListEnabledForTag(deckId: String, tag: String) {
        commands.execute(.toggleListByTag, deckId, tag)
    }

    func doDecksChanged(decks: [Deck], completion: @escaping (Result<Void, Error>) -> Void) {
        self.decks = decks
        onDecks(decks)
        completion(.success(()))
    }

    func doTagMappingChanged(tapMapping: [String : String], completion: @escaping (Result<Void, Error>) -> Void) {
        self.tapMapping = tapMapping
        completion(.success(()))
    }
}

extension Container {
    var deck: Factory<DeckBinding> {
        self { DeckBinding() }.singleton
    }
}
