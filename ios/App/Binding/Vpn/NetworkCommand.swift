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

struct NetworkStatus {
    let active: Bool
    let inProgress: Bool
    let gatewayId: String?
    let pauseSeconds: Int

    func hasGateway() -> Bool {
        return gatewayId != nil
    }
}

extension NetworkStatus {
    static func disconnected() -> NetworkStatus {
        return NetworkStatus(active: false, inProgress: false, gatewayId: nil, pauseSeconds: 0)
    }

    static func inProgress() -> NetworkStatus {
        return NetworkStatus(active: false, inProgress: true, gatewayId: nil, pauseSeconds: 0)
    }

    static func noPermissions() -> NetworkStatus {
        return NetworkStatus(active: false, inProgress: false, gatewayId: nil, pauseSeconds: 0)
    }
}

enum NetworkCommand: String {
    case request = "request"
    case report = "report"
    case pause = "pause"
    case connect = "connect"
}

enum ReportCommandResponse: String {
    case on = "on"
    case off = "off"
}
