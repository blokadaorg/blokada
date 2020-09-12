//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
