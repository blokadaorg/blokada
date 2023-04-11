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

struct CurrentLease {
    let lease: Lease?
}

class PlusLeaseBinding: PlusLeaseOps {
    let leases = CurrentValueSubject<[Lease], Never>([])
    let currentLease = CurrentValueSubject<CurrentLease, Never>(
        CurrentLease(lease: nil)
    )

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    init() {
        PlusLeaseOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func deleteLease(_ lease: Lease) {
        commands.execute(.deleteLease, lease.publicKey)
    }

    func doLeasesChanged(leases: [Lease], completion: @escaping (Result<Void, Error>) -> Void) {
        self.leases.send(leases)
        completion(.success(()))
    }

    func doCurrentLeaseChanged(lease: Lease?, completion: @escaping (Result<Void, Error>) -> Void) {
        currentLease.send(CurrentLease(lease: lease))
        completion(.success(()))
    }
}

extension Container {
    var plusLease: Factory<PlusLeaseBinding> {
        self { PlusLeaseBinding() }.singleton
    }
}
