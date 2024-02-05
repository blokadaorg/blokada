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

class PackDetailViewModel: ObservableObject {

    @Injected(\.filter) private var filter
    @Injected(\.cloud) private var device
    @Injected(\.commands) private var commands

    private var cancellables = Set<AnyCancellable>()

    private var vm = ViewModels.packs

    @Published var pack: Pack {
        didSet {
            self.on = pack.status.installed
        }
    }

    @Published var on: Bool = false
    @Published var selected: Bool = false

    private let log = BlockaLogger("Pack")

    init(packId: String) {
        self.pack = vm.byId(packId)!
        self.on = self.pack.status.installed
        selected = (packId == vm.sectionStack.first)
    }

    func changeConfig(config: PackConfig, fail: @escaping Faile) {
        filter.toggleFilterOption(filterName: pack.id, optionName: config)
    }

    func install(fail: @escaping Faile) {
        self.log.v("Installing pack")
        filter.enableFilter(filterName: pack.id, enabled: true)
   }

    func uninstall(fail: @escaping Faile) {
        self.log.v("uninstalling pack")
        filter.enableFilter(filterName: pack.id, enabled: false)
    }

    func isSafeSearch() -> Bool {
        return device.safeSearch
    }

    func toggleSafeSearch() {
        var param = "1"
        if device.safeSearch {
            param = "0"
        }
        commands.execute(.setSafeSearch, param)
    }
}
