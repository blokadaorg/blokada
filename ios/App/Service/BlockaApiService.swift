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
//    func postAppleCheckout(request: AppleCheckoutRequest) -> AnyPublisher<JsonAccount, Error>
//    func postAppleDeviceToken(request: AppleDeviceTokenRequest) -> AnyPublisher<Ignored, Error>
}

class BlockaApiService: BlockaApiServiceIn {

    private let log = BlockaLogger("BlockaApi")
    private let decoder = blockaDecoder
    private let encoder = blockaEncoder

//    func postAppleCheckout(request: AppleCheckoutRequest) -> AnyPublisher<JsonAccount, Error> {
//        return self.client.post("/v2/apple/checkout", payload: request)
//        .decode(type: AccountWrapper.self, decoder: self.decoder)
//        .tryMap { it in it.account }
//        .eraseToAnyPublisher()
//    }
//
//    func postAppleDeviceToken(request: AppleDeviceTokenRequest) -> AnyPublisher<Ignored, Error> {
//        return self.client.post("/v2/apple/device", payload: request)
//        .tryMap { _ in true }
//        .eraseToAnyPublisher()
//    }
}
