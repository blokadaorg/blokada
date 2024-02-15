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

    @Injected(\.flutter) private var flutter
    @Injected(\.filter) private var filter
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
            doFilter()
        }
    }

    @Published var showTag: String? = nil

    @Published var showError: Bool = false

    private let log = BlockaLogger("Pack")

    init() {
        filtering = self.flutter.isFlavorFamily ? 3 : 0
        filter.onFilters = { filters, selections in
            var packs = [Pack]()
            var tags = [Tag]()
            filters.forEach { filter in
                // Get the pack template from the data source
                var pack = self.dataSource.packs.first { it in
                    it.id == filter.filterName
                }

                if var pack = pack {
                    // Go through each list items of the deck
                    var selection = selections.first { it in
                        it.filterName == filter.filterName
                    }
                    
                    if var selection = selection {
                        selection.options.forEach { optionName in
                            pack = pack.changeStatus(installed: true, config: optionName)
                            
                            // Respect the bundle enabled flag
                            pack = pack.changeStatus(installed: true)
                        }
                    }

                    packs.append(pack)
                }
            }
            self.allPacks = packs
            self.findTags()
            self.doFilter()
            self.objectWillChange.send()
        }
        onTabPayloadChanged()
    }

    func doFilter() {
        if filtering == 1 {
            self.packs = allPacks.filter { pack in
                pack.status.installed
            }
        } else if filtering == 2 {
            self.packs = allPacks.filter { pack in
                self.activeTags.intersection(pack.tags).isEmpty != true
            }
        } else if filtering == 0 {
            self.packs = allPacks.filter { pack in
                pack.tags.contains(Pack.recommended) /* && !pack.status.installed */
            }
        } else {
            self.packs = allPacks
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
        doFilter()
    }
    
    func byId(_ id: String) -> Pack? {
        return allPacks.first { it in
            it.id == id
        }
    }

    func getListName(_ listId: String) -> String {
        if let tag = filter.listsToTags[listId] {
            let components = tag.split(separator: "/").map(String.init)
            if components.count == 2 {
                let id = components[0]
                let config = components[1]
                let title = dataSource.packs.first { it in
                    it.id == id
                }?.meta.title

                guard let title = title else {
                    return tag
                }

                return "\(title) (\(config.capitalizingFirstLetter()))"
            } else {
                return tag
            }
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
