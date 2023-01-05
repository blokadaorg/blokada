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

class PackDetailViewModel: ObservableObject {

    private let packRepo = Repos.packRepo
    private let navRepo = Repos.navRepo
    private var cancellables = Set<AnyCancellable>()

    @Published var pack: Pack {
        didSet {
            self.on = pack.status.installed
        }
    }

    @Published var on: Bool = false
    @Published var selected: Bool = false

    private let log = BlockaLogger("Pack")

    init(pack: Pack) {
        self.pack = pack
        self.on = self.pack.status.installed
        onNavChanged()
    }

    private func onNavChanged() {
        navRepo.sectionHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.selected = (it as? Pack) == self.pack
        })
        .store(in: &cancellables)
    }

    func changeConfig(config: PackConfig, fail: @escaping Faile) {
        packRepo.changeConfig(pack: pack, config: config)
        .receive(on: RunLoop.main)
        .sink(onFailure: { err in fail(err)})
        .store(in: &cancellables)
    }

    func install(fail: @escaping Faile) {
        self.log.v("Installing pack")
        packRepo.installPack(pack)
        .receive(on: RunLoop.main)
        .sink(onFailure: { err in fail(err)} )
        .store(in: &cancellables)
   }

    func uninstall(fail: @escaping Faile) {
        self.log.v("uninstalling pack")
        packRepo.uninstallPack(pack)
        .receive(on: RunLoop.main)
        .sink(onFailure: { err in fail(err)} )
        .store(in: &cancellables)
    }

}
