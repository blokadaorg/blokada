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
    private var cancellables = Set<AnyCancellable>()

    @Published var pack: Pack {
        didSet {
            self.on = pack.status.installed
        }
    }

    @Published var on: Bool = false {
        didSet {
        }
    }

    private let log = Logger("Pack")

    init(pack: Pack) {
        self.pack = pack
        self.on = self.pack.status.installed
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

    func openCreditUrl() {
        if pack.meta.creditUrl.isEmpty {
            self.log.w("No credit url")
            return
        }

        if let url = URL(string: pack.meta.creditUrl) {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                Links.openInBrowser(components)
            }
        }
    }
}
