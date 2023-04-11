//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import Factory

class PacksViewModel: ObservableObject {

    @Injected(\.deck) private var deck
    @Injected(\.stage) private var stage


    private lazy var dataSource = PackDataSource()

    private var cancellables = Set<AnyCancellable>()
    
    @Published var sectionStack = [String]()

    @Published var packs = [Pack]()
    @Published var allTags = [Tag]()

    var allPacks = [Pack]()
    var allTagsSet = Set<Tag>()
    var activeTags = Set<Tag>()

    @Published var filtering = 0 {
        didSet {
            filter()
        }
    }

    @Published var showTag: String? = nil

    @Published var showError: Bool = false

    private let log = BlockaLogger("Pack")

    init() {
        deck.onDecks = { it in
            var packs = [Pack]()
            var tags = [Tag]()
            it.forEach { deck in
                // Get the pack template from the data source
                var pack = self.dataSource.packs.first { it in
                    it.id == deck.deckId
                }

                if var pack = pack {
                    // Go through each list items of the deck
                    deck.items.keys.forEach { listId in
                        let item = deck.items[listId]!!
                        // Mark them as active in the pack
                        if item.enabled {
                            pack = pack.changeStatus(installed: true, config: item.tag)
                        }
                    }
                    // Respect the bundle enabled flag
                    pack = pack.changeStatus(installed: deck.enabled)
                    packs.append(pack)
                }
            }
            self.allPacks = packs
            self.findTags()
            self.filter()
            self.objectWillChange.send()
        }
        onTabPayloadChanged()
    }

    func filter() {
        if filtering == 1 {
            self.packs = allPacks.filter { pack in
                pack.status.installed
            }
        } else if filtering == 2 {
            self.packs = allPacks.filter { pack in
                self.activeTags.intersection(pack.tags).isEmpty != true
            }
        } else {
            self.packs = allPacks.filter { pack in
                pack.tags.contains(Pack.recommended) /* && !pack.status.installed */
            }
        }
    }

    private func findTags() {
        self.allTags = self.allPacks.flatMap { $0.tags }.unique().filter { $0 != Pack.recommended }
        self.allTagsSet = Set(self.allTags)
        self.activeTags = self.allTags.isEmpty ? Set() : Set(arrayLiteral: self.allTags[0])
    }

    func isTagActive(_ tag: Tag) -> Bool {
        return activeTags.contains(tag)
    }

    func flipTag(_ tag: Tag) {
        if isTagActive(tag) {
            //activeTags.remove(tag)
            activeTags = []
        } else {
            //activeTags.insert(tag)
            activeTags = [tag]
        }
        filter()
    }
    
    func byId(_ id: String) -> Pack? {
        return allPacks.first { it in
            it.id == id
        }
    }

    func getListName(_ listId: String) -> String {
        if let packId = deck.getDeckIdForList(listId) {
            return packs.first { it in
                it.id == packId
            }?.meta.title ?? listId
        } else {
            return listId
        }
    }

    private func onTabPayloadChanged() {
        stage.tabPayload
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            if let it = it, let pack = self.byId(it) {
                self.sectionStack = [pack.id]
            } else {
                self.sectionStack = []
            }
        })
        .store(in: &cancellables)
    }
}
