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
}

class BlockaApiService2: BlockaApiServiceIn {

    private let log = Logger("BlockaApi")
    private let decoder = blockaDecoder
    private let encoder = blockaEncoder

    private lazy var client = Services.http

    func getAccount(id: AccountId) -> AnyPublisher<Account, Error> {
        return self.client.get("/v1/account?account_id=\(id)")
        .decode(type: AccountWrapper.self, decoder: self.decoder)
        .tryMap { it in it.account }
        .eraseToAnyPublisher()
    }

    func postNewAccount() -> AnyPublisher<Account, Error> {
        return self.client.post("/v1/account", payload: nil)
        .decode(type: AccountWrapper.self, decoder: self.decoder)
        .tryMap { it in it.account }
        .eraseToAnyPublisher()
    }

    func getDevice(id: AccountId) -> AnyPublisher<DevicePayload, Error> {
        return self.client.get("/v1/device?account_id=\(id)")
        .decode(type: DevicePayload.self, decoder: self.decoder)
        .eraseToAnyPublisher()
    }

    func putDevice(request: DeviceRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.put("/v1/device", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func postAppleCheckout(request: AppleCheckoutRequest) -> AnyPublisher<Account, Error> {
        return self.client.post("/v1/apple/checkout", payload: request)
        .decode(type: AccountWrapper.self, decoder: self.decoder)
        .tryMap { it in it.account }
        .eraseToAnyPublisher()
    }

    func postAppleDeviceToken(request: AppleDeviceTokenRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.post("/v1/apple/device", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func getActivity(id: AccountId) -> AnyPublisher<[Activity], Error> {
        return self.client.get("/v1/activity?account_id=\(id)")
        .decode(type: ActivityWrapper.self, decoder: self.decoder)
        .tryMap { it in it.activity }
        .eraseToAnyPublisher()
    }

    func getCustomList(id: AccountId) -> AnyPublisher<[CustomListEntry], Error> {
        return self.client.get("/v1/customlist?account_id=\(id)")
        .decode(type: ExceptionWrapper.self, decoder: self.decoder)
        .tryMap { it in it.customlist }
        .eraseToAnyPublisher()
    }

    func postCustomList(request: CustomListRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.post("/v1/customlist", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func deleteCustomList(request: CustomListRequest) -> AnyPublisher<Ignored, Error> {
        return self.client.delete("/v1/customlist", payload: request)
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

}
