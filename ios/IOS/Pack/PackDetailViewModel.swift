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

class PackDetailViewModel: ObservableObject {

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
    private let service = PackService.shared

    init(pack: Pack) {
        self.pack = pack
        self.on = self.pack.status.installed
    }

    func changeConfig(config: PackConfig, fail: @escaping Fail) {
        self.service.changeConfig(pack: self.pack, config: config, fail: fail)
    }

    func install(fail: @escaping Fail) {
        self.log.v("Installing pack")
        self.service.installPack(pack: pack, ok: { pack in

        }, fail: { error in
            onMain {
                self.log.e("Failed installing pack".cause(error))
                fail(error)
            }
        })
   }

    func uninstall(fail: @escaping Fail) {
        self.log.v("uninstalling pack")
        self.service.uninstallPack(pack: pack, ok: { pack in

        }, fail: { error in
            onMain {
                self.log.e("Failed uninstalling pack".cause(error))
                fail(error)
            }
        })
    }

    func unsetBadge() {
        self.service.unsetBadge(pack: self.pack)
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
