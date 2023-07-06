//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import Combine

extension Gateway {
    func niceName() -> String {
        return location.components(separatedBy: "-")
            .map { $0.capitalizingFirstLetter() }
            .joined(separator: " ")
    }
}

extension Gateway: Equatable {
    static func == (lhs: Gateway, rhs: Gateway) -> Bool {
        return
            lhs.publicKey == rhs.publicKey &&
            lhs.ipv4 == rhs.ipv4 &&
            lhs.ipv6 == rhs.ipv6 &&
            lhs.port == rhs.port
    }
}

struct GatewaySelection {
    let gateway: Gateway?
}

class PlusGatewayBinding: PlusGatewayOps {
    let gateways = CurrentValueSubject<[Gateway], Never>([])
    let selected = CurrentValueSubject<GatewaySelection, Never>(
        GatewaySelection(gateway: nil)
    )

    @Injected(\.flutter) private var flutter

    init() {
        PlusGatewayOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doSelectedGatewayChanged(publicKey: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        let gateway = gateways.value.first { it in
            it.publicKey == publicKey
        }
        selected.send(GatewaySelection(gateway: gateway))
        completion(.success(()))
    }

    func doGatewaysChanged(gateways: [Gateway], completion: @escaping (Result<Void, Error>) -> Void) {
        self.gateways.send(gateways)
        self.selected.send(self.selected.value)
        completion(.success(()))
    }
}

extension Container {
    var plusGateway: Factory<PlusGatewayBinding> {
        self { PlusGatewayBinding() }.singleton
    }
}
