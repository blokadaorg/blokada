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

struct LocationViewModel {

    let gateway: Gateway
    let selectedGateway: Gateway?

    init(gateway: Gateway, selectedGateway: Gateway?) {
        self.gateway = gateway
        self.selectedGateway = selectedGateway
    }

    init(mocked: String) {
        gateway = Gateway(public_key: mocked, region: "", location: mocked,
                          resource_usage_percent: 0, ipv4: "", ipv6: "",
                          port: 0, tags: nil)
        selectedGateway = nil
    }

    var isActive: Bool {
        return gateway.public_key == selectedGateway?.public_key
    }

    var name: String {
        return gateway.niceName()
    }
}

extension LocationViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(gateway.public_key)
    }
}

extension LocationViewModel: Equatable {
    static func == (lhs: LocationViewModel, rhs: LocationViewModel) -> Bool {
        lhs.gateway.public_key == rhs.gateway.public_key
    }
}
