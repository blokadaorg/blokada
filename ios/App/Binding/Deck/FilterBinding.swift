//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2024 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory

class FilterBinding: FilterOps {

    var filters: [Filter] = []
    var selections: [Filter] = []
    var listsToTags: [String : String] = [:]

    var onFilters: ([Filter], [Filter]) -> Void = { _, _ in }

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    init() {
        FilterOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func enableFilter(filterName: String, enabled: Bool) {
        if enabled {
            commands.execute(.enableDeck, filterName)
        } else {
            commands.execute(.disableDeck, filterName)
        }
    }

    func toggleFilterOption(filterName: String, optionName: String) {
        commands.execute(.toggleListByTag, filterName, optionName)
    }

    func doFiltersChanged(filters: [Filter], completion: @escaping (Result<Void, Error>) -> Void) {
        self.filters = filters
        onFilters(filters, selections)
        completion(.success(()))
    }

    func doFilterSelectionChanged(selections: [Filter], completion: @escaping (Result<Void, Error>) -> Void) {
        self.selections = selections
        onFilters(filters, selections)
        completion(.success(()))
    }

    func doListToTagChanged(listToTag: [String : String], completion: @escaping (Result<Void, Error>) -> Void) {
        self.listsToTags = listToTag
        completion(.success(()))
    }
}

extension Container {
    var filter: Factory<FilterBinding> {
        self { FilterBinding() }.singleton
    }
}
