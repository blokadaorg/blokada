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

extension Lease {
    func activeUntil() -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = blockaDateFormat
        guard let date = dateFormatter.date(from: expires) else {
            dateFormatter.dateFormat = blockaDateFormatNoNanos
            guard let date = dateFormatter.date(from: expires) else {
                return Date(timeIntervalSince1970: 0)
            }
            return date
        }
        return date
    }

    func isActive() -> Bool {
        return activeUntil() > Date()
    }

    func niceName() -> String {
        return alias ?? String(publicKey.prefix(5))
    }
}

extension Lease: Equatable {
    static func == (lhs: Lease, rhs: Lease) -> Bool {
        return lhs.accountId == rhs.accountId
            && lhs.publicKey == rhs.publicKey
            && lhs.gatewayId == rhs.gatewayId
            && lhs.expires == rhs.expires
            && lhs.alias == rhs.alias
            && lhs.vip4 == rhs.vip4
            && lhs.vip6 == rhs.vip6
    }
}

// Used to do stuff before lease / account expires (and we may get net cutoff)
extension Date {
    func shortlyBefore() -> Date {
        let seconds = DateComponents(second: -10)
        return Calendar.current.date(byAdding: seconds, to: self) ?? self
    }
}

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
