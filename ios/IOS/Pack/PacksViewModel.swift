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

class PacksViewModel: ObservableObject {

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

    private let log = Logger("Pack")
    private let service = PackService.shared

    init(tabVM: TabViewModel) {
        service.onPacksUpdated = { packs in
            self.allPacks = packs
            self.findTags()
            self.filter()
            tabVM.packsBadge = self.service.countBadges()
            self.objectWillChange.send()
        }
    }

    func fetch() {
        self.log.v("Fetching packs")
        service.fetchPacks(ok: { packs in
            // we receive them through the callback in init
        }) { error in
            self.log.e("Failed fetching packs".cause(error))
        }
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
}
