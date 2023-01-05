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
import UIKit

protocol BlockaApiServiceIn {
    func getAccount(id: AccountId) -> AnyPublisher<Account, Error>
    func postNewAccount() -> AnyPublisher<Account, Error>
    func getDevice(id: AccountId) -> AnyPublisher<DevicePayload, Error>
    func putDevice(request: DeviceRequest) -> AnyPublisher<Ignored, Error>
    func postAppleCheckout(request: AppleCheckoutRequest) -> AnyPublisher<Account, Error>
    func postAppleDeviceToken(request: AppleDeviceTokenRequest) -> AnyPublisher<Ignored, Error>
    func getActivity(id: AccountId) -> AnyPublisher<[Activity], Error>
    func getCustomList(id: AccountId) -> AnyPublisher<[CustomListEntry], Error>
    func postCustomList(request: CustomListRequest) -> AnyPublisher<Ignored, Error>
    func deleteCustomList(request: CustomListRequest) -> AnyPublisher<Ignored, Error>
    func getStats(id: AccountId) -> AnyPublisher<CounterStats, Error>
    func getBlocklists(id: AccountId) -> AnyPublisher<[Blocklist], Error>
    func getGateways() -> AnyPublisher<[Gateway], Error>
    func getLeases(id: AccountId) -> AnyPublisher<[Lease], Error>
    func postLease(request: LeaseRequest) -> AnyPublisher<Lease, Error>
    func deleteLease(request: LeaseRequest) -> AnyPublisher<Ignored, Error>
}

class BlockaApiService: BlockaApiServiceIn {

    private let log = BlockaLogger("BlockaApi")
    private let decoder = blockaDecoder
    private let encoder = blockaEncoder

    private lazy var client = Repos.httpRepo

    func getAccount(id: AccountId) -> AnyPublisher<Account, Error> {
        return self.client.get("/v2/account?account_id=\(id)")
        .decode(type: AccountWrapper.self, decoder: self.decoder)
        .tryMap { it in it.account }
//        .tryMap { it in
//            return Account(
//                id: it.id,
//                active_until: self.fakeExpireTime(),
//                active: self.accountOver > Date(),
//                type: (self.accountOver > Date()) ? "plus" : "libre"
//            )
//        }
        .eraseToAnyPublisher()
    }

    func postNewAccount() -> AnyPublisher<Account, Error> {
        return self.client.post("/v2/account", payload: nil)
        .decode(type: AccountWrapper.self, decoder: self.decoder)
        .tryMap { it in it.account }
        .eraseToAnyPublisher()
    }

    func getDevice(id: AccountId) -> AnyPublisher<DevicePayload, Error> {
        return self.client.get("/v2/device?account_id=\(id)")
        .decode(type: DevicePayload.self, decoder: self.decoder)
        .eraseToAnyPublisher()
    }

    func putDevice(request: DeviceRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.put("/v2/device", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func postAppleCheckout(request: AppleCheckoutRequest) -> AnyPublisher<Account, Error> {
        return self.client.post("/v2/apple/checkout", payload: request)
        .decode(type: AccountWrapper.self, decoder: self.decoder)
        .tryMap { it in it.account }
        .eraseToAnyPublisher()
    }

    func postAppleDeviceToken(request: AppleDeviceTokenRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.post("/v2/apple/device", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func getActivity(id: AccountId) -> AnyPublisher<[Activity], Error> {
        return self.client.get("/v2/activity?account_id=\(id)")
        .decode(type: ActivityWrapper.self, decoder: self.decoder)
        .tryMap { it in it.activity }
        .eraseToAnyPublisher()
    }

    func getCustomList(id: AccountId) -> AnyPublisher<[CustomListEntry], Error> {
        return self.client.get("/v2/customlist?account_id=\(id)")
        .decode(type: ExceptionWrapper.self, decoder: self.decoder)
        .tryMap { it in it.customlist }
        .eraseToAnyPublisher()
    }

    func postCustomList(request: CustomListRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.post("/v2/customlist", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func deleteCustomList(request: CustomListRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.delete("/v2/customlist", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func getStats(id: AccountId) -> AnyPublisher<CounterStats, Error> {
        return self.client.get("/v2/stats?account_id=\(id)")
        .decode(type: CounterStats.self, decoder: self.decoder)
        .tryMap { it in it }
        .eraseToAnyPublisher()
    }

    func getBlocklists(id: AccountId) -> AnyPublisher<[Blocklist], Error> {
        return self.client.get("/v2/list?account_id=\(id)")
        .decode(type: BlocklistWrapper.self, decoder: self.decoder)
        .tryMap { it in it.lists }
        .eraseToAnyPublisher()
    }

    func getGateways() -> AnyPublisher<[Gateway], Error> {
        return self.client.get("/v2/gateway")
        .decode(type: Gateways.self, decoder: self.decoder)
        .tryMap { it in it.gateways }
        .eraseToAnyPublisher()
    }

    func getLeases(id: AccountId) -> AnyPublisher<[Lease], Error> {
        return self.client.get("/v2/lease?account_id=\(id)")
        .decode(type: Leases.self, decoder: self.decoder)
        .tryMap { it in it.leases }
//        .tryMap { it in
//            it.map {
//                if $0.public_key == "dt2ePyI/EToftiG4S/h6TTYfJi+8lbV64VsqOZmC6jc=" {
//                    return Lease(
//                        account_id: $0.account_id,
//                        public_key: $0.public_key,
//                        gateway_id: $0.gateway_id,
//                        expires: self.fakeExpireTime(),
//                        alias: $0.alias,
//                        vip4: $0.vip4,
//                        vip6: $0.vip6
//                    )
//                } else {
//                    return $0
//                }
//            }
//        }
        .eraseToAnyPublisher()
    }

    var accountOver: Date = Date()
    private func createFakeExp() {
        let seconds = DateComponents(second: 120)
        let date = Calendar.current.date(byAdding: seconds, to: Date()) ?? Date()
        accountOver = date
    }
    init() {
        createFakeExp()
    }
    
    private func fakeExpireTime() -> String {
        return blockaDateFormatter.string(from: accountOver)
    }

    func postLease(request: LeaseRequest) -> AnyPublisher<Lease, Error> {
        return self.client.post("/v2/lease", payload: request)
        .decode(type: LeaseWrapper.self, decoder: self.decoder)
        .tryMap { it in it.lease }
        // Convert to CommonError if known error
        .tryCatch { err -> AnyPublisher<Lease, Error> in
            if let e = err as? NetworkError {
                switch e {
                  case .http(let code):
                    if code == 403 {
                        throw CommonError.tooManyLeases
                    } else {
                        throw err
                    }
                }
            } else {
                throw err
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteLease(request: LeaseRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.delete("/v2/lease", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

}
