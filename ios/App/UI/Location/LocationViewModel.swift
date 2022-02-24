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
        case "CH":
            return "flag_ch"
        case "AU":
            return "flag_au"
        case "SG":
            return "flag_sg"
        case "ES":
            return "flag_es"
        case "IT":
            return "flag_it"
        case "BG":
            return "flag_bg"
        case "US":
            return "flag_us"
        default:
            return "flag_un"
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
