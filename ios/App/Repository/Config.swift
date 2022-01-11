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
import Combine

class Config {

    static let shared = Config()

    private lazy var accounts = Repos.accountRepo.accountHot
    private var cancellables = Set<AnyCancellable>()

    private let log = Logger("Config")
    private let decoder = initJsonDecoder()
    private let encoder = initJsonEncoder()

    // We persist config either on local storage, in the iCloud, or in RAM only
    private let localStorage = UserDefaults.standard
    private let iCloud = NSUbiquitousKeyValueStore()
    private let oldiCloud = KeychainSwift()

    private let _deviceToken = Atomic<DeviceToken?>(nil)
    private let _account = Atomic<Account?>(nil)
    private let _keypair = Atomic<Keypair?>(nil)
    private let _lease = Atomic<Lease?>(nil)

  

    func rateAppShown() -> Bool {
        return iCloud.bool(forKey: "rateAppShown")
    }

    func firstRun() -> Bool {
        return localStorage.bool(forKey: "notFirstRun")
    }


    func expireSeen() -> Bool {
        return localStorage.bool(forKey: "expireSeen")
    }

   
    func markRateAppShown() {
        // Persist in the cloud to not bother same user again
        iCloud.set(true, forKey: "rateAppShown")
        iCloud.synchronize()
    }

    func markFirstRun() {
        localStorage.set(true, forKey: "notFirstRun")
    }

    func markExpireSeen(_ can: Bool) {
        localStorage.set(can, forKey: "expireSeen")
    }

}
