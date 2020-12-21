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
import SwiftUI

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
                          port: 0, tags: nil, country: "DE")
        selectedGateway = nil
    }

    var isActive: Bool {
        return gateway.public_key == selectedGateway?.public_key
    }

    var name: String {
        return gateway.niceName()
    }

    func getFlag() -> String {
        switch (gateway.country) {
        case "AE":
            return "flag_ae"
        case "CA":
            return "flag_ca"
        case "DE":
            return "flag_de"
        case "FR":
            return "flag_fr"
        case "GB":
            return "flag_gb"
        case "JP":
            return "flag_jp"
        case "NL":
            return "flag_nl"
        case "SE":
            return "flag_se"
        default:
            return "flag_us"
        }
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
