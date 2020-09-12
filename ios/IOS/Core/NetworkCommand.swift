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

struct NetworkStatus {
    let active: Bool
    let inProgress: Bool
    let gatewayId: GatewayId?
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
    case connect = "connect"
    case disconnect = "disconnect"
    case request = "request"
    case report = "report"
}

enum ReportCommandResponse: String {
    case on = "on"
    case off = "off"
}
