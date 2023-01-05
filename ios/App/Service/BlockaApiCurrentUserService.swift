//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine

/**
 A wrapper on top of BlockaApiService that uses current user
 info to expose convenient api relevant to the current user.
 */
class BlockaApiCurrentUserService {

    lazy var client = Services.api

    private lazy var accountRepo = Repos.accountRepo
    private lazy var envRepo = Services.env

    func getDeviceForCurrentUser() -> AnyPublisher<DevicePayload, Error> {
        return accountRepo.accountHot.first()
        .flatMap { it in
            self.client.getDevice(id: it.account.id)
        }
        .eraseToAnyPublisher()
    }

    func putActivityRetentionForCurrentUser(_ retention: String) -> AnyPublisher<Ignored, Error> {
        return accountRepo.accountHot.first()
        .map { it in DeviceRequest(
            account_id: it.account.id,
            lists: nil,
            retention: retention,
            paused: nil
        )}
        .flatMap { it in self.client.putDevice(request: it) }
        .eraseToAnyPublisher()
    }

    func putPausedForCurrentUser(_ paused: Bool) -> AnyPublisher<Ignored, Error> {
        return accountRepo.accountHot.first()
        .map { it in DeviceRequest(
            account_id: it.account.id,
            lists: nil,
            retention: nil,
            paused: paused
        )}
        .flatMap { it in self.client.putDevice(request: it) }
        .eraseToAnyPublisher()
    }

    func putBlocklistsForCurrentUser(_ lists: CloudBlocklists) -> AnyPublisher<Ignored, Error> {
        return accountRepo.accountHot.first()
        .map { it in DeviceRequest(
            account_id: it.account.id,
            lists: lists,
            retention: nil,
            paused: nil
        )}
        .flatMap { it in self.client.putDevice(request: it) }
        .eraseToAnyPublisher()
    }

    func postAppleCheckoutForCurrentUser(_ receipt: String) -> AnyPublisher<Account, Error> {
        return accountRepo.accountHot.first()
        .map { it in AppleCheckoutRequest(
            account_id: it.account.id,
            receipt: receipt
        )}
        .flatMap { it in self.client.postAppleCheckout(request: it) }
        .eraseToAnyPublisher()
    }

    func postAppleDeviceTokenForCurrentUser(deviceToken: Data) -> AnyPublisher<Ignored, Error> {
        return accountRepo.accountHot.first()
        .map { it in AppleDeviceTokenRequest(
            account_id: it.account.id,
            public_key: it.keypair.publicKey,
            device_token: deviceToken
        )}
        .flatMap { it in self.client.postAppleDeviceToken(request: it) }
        .eraseToAnyPublisher()
    }

    func getActivityForCurrentUserAndDevice() -> AnyPublisher<[Activity], Error> {
        return accountRepo.accountIdHot.first()
        .flatMap { it in self.client.getActivity(id: it) }
        //.tryMap { it in it.filter { $0.device_name == self.envRepo.deviceName }}
        .eraseToAnyPublisher()
    }

    func getCustomListForCurrentUser() -> AnyPublisher<[CustomListEntry], Error> {
        return accountRepo.accountIdHot.first()
        .flatMap { it in self.client.getCustomList(id: it) }
        .eraseToAnyPublisher()
    }

    func postCustomListForCurrentUser(_ entry: CustomListEntry) -> AnyPublisher<Ignored, Error> {
        return accountRepo.accountIdHot.first()
        .map { it in CustomListRequest(
            account_id: it,
            domain_name: entry.domain_name,
            action: entry.action
        )}
        .flatMap { it in self.client.postCustomList(request: it) }
        .eraseToAnyPublisher()
    }

    func deleteCustomListForCurrentUser(_ domainName: String) -> AnyPublisher<Ignored, Error> {
        return accountRepo.accountIdHot.first()
        .map { it in CustomListRequest(
            account_id: it,
            domain_name: domainName,
            action: "fallthrough"
        )}
        .flatMap { it in self.client.deleteCustomList(request: it) }
        .eraseToAnyPublisher()
    }

    func getStatsForCurrentUser() -> AnyPublisher<CounterStats, Error> {
        return accountRepo.accountIdHot.first()
        .flatMap { it in self.client.getStats(id: it) }
        .eraseToAnyPublisher()
    }

    func getBlocklistsForCurrentUser() -> AnyPublisher<[Blocklist], Error> {
        return accountRepo.accountIdHot.first()
        .flatMap { it in self.client.getBlocklists(id: it) }
        .eraseToAnyPublisher()
    }

    func getLeasesForCurrentUser() -> AnyPublisher<[Lease], Error> {
        return accountRepo.accountIdHot.first()
        .flatMap { it in self.client.getLeases(id: it) }
        .eraseToAnyPublisher()
    }

    func deleteLeasesForCurrentUserAndDevice() -> AnyPublisher<Ignored, Error> {
        return getLeasesForCurrentUser()
        .tryMap { leases -> LeaseRequest in
            if let it = leases.first(where: { $0.alias == self.envRepo.aliasForLease }) {
                return LeaseRequest(
                    account_id: it.account_id,
                    public_key: it.public_key,
                    gateway_id: it.gateway_id,
                    alias: it.alias
                )
            } else {
                throw "Found no lease for current alias"
            }
        }
        .flatMap { request -> AnyPublisher<Ignored, Error> in
            BlockaLogger.w("BlockaApi", "Deleting one active lease for current alias")
            return self.client.deleteLease(request: request)
        }
        .eraseToAnyPublisher()
    }

}
