//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine

// A HTTP client that makes requests through a protected socked that skips the tunnel.
class HttpProtectedService: HttpServiceIn {

    private lazy var env = Services.env

    private lazy var netx = Services.netx

    private let bgQueue = DispatchQueue(label: "HttpProtectedBgQueue")

    func get(_ path: String) -> AnyPublisher<Data, Error> {
        BlockaLogger.v("HttpProtect", "GET through a protected socket")
        return makeProtectedRequest(path, method: "GET")
        .tryCatch { error in
            // A delayed retry (total 3 attemps spread 1-5 sec at random)
            return self.makeProtectedRequest(path, method: "GET")
                .delay(for: DispatchQueue.SchedulerTimeType.Stride(integerLiteral: Int.random(in: 1..<5)), scheduler: self.bgQueue)
                .retry(2)
        }
        .eraseToAnyPublisher()
    }

    // TODO: should post/put also repeat on fail?
    func postOrPut(_ path: String, method: String, payload: Encodable?) -> AnyPublisher<Data, Error> {
        BlockaLogger.v("HttpProtect", "POST/PUT through a protected socket")
        var body = ""
        if payload != nil {
            guard let payloadEncoded = payload?.toJson() else {
                return Fail(error: "HttpProtectedService: could not encode payload")
                    .eraseToAnyPublisher()
            }
            body = payloadEncoded
        }

        return makeProtectedRequest(path, method: method, body: body)
        .eraseToAnyPublisher()
    }

    private func makeProtectedRequest(_ path: String, method: String, body: String = "") -> AnyPublisher<Data, Error> {
        guard let url = URL(string: "\(self.env.baseUrl)\(path)") else {
            return Fail(error: "HttpProtectedService: invalid url: \(path)")
                .eraseToAnyPublisher()
        }

        return netx.makeProtectedRequest(url: url.absoluteString, method: method, body: body)
        .tryMap { it in
            if let data = it.data(using: .utf8) {
                return data
            } else {
                throw "nil response from netx"
            }
        }
        .eraseToAnyPublisher()
    }

}
