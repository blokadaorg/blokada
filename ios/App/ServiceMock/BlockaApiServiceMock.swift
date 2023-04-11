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

class BlockaApiServiceMock: BlockaApiServiceIn {

    var mockAccount = { id in
        Mocks.justAccount(id ?? "wearetesting")
    }

    func getAccount(id: AccountId) -> AnyPublisher<Account, Error> {
        return mockAccount(id)
    }

    func postNewAccount() -> AnyPublisher<Account, Error> {
        return mockAccount(nil)
    }

    func getDevice(id: AccountId) -> AnyPublisher<DevicePayload, Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func putDevice(request: DeviceRequest) -> AnyPublisher<Ignored, Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func postAppleCheckout(request: AppleCheckoutRequest) -> AnyPublisher<Account, Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func postAppleDeviceToken(request: AppleDeviceTokenRequest) -> AnyPublisher<Ignored, Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func getActivity(id: AccountId) -> AnyPublisher<[Activity], Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func getCustomList(id: AccountId) -> AnyPublisher<[CustomListEntry], Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func postCustomList(request: CustomListRequest) -> AnyPublisher<Ignored, Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func deleteCustomList(request: CustomListRequest) -> AnyPublisher<Ignored, Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func getStats(id: AccountId) -> AnyPublisher<CounterStats, Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func getBlocklists(id: AccountId) -> AnyPublisher<[Blocklist], Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func getGateways() -> AnyPublisher<[Gateway], Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func getLeases(id: AccountId) -> AnyPublisher<[Lease], Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }

    func postAppleCheckout(request: AppleCheckoutRequest) -> AnyPublisher<JsonAccount, Error> {
        return Fail(error: "Unsupported in mock").eraseToAnyPublisher()
    }
    
}
