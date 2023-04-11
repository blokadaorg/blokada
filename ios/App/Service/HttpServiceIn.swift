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
import Factory

protocol HttpServiceIn {
    func get(_ path: String) -> AnyPublisher<Data, Error>
    func postOrPut(_ path: String, method: String, payload: Encodable?) -> AnyPublisher<Data, Error>
}

class HttpStandardService: HttpServiceIn {

    @Injected(\.env) private var env

    private let session = URLSession.shared
    private let bgQueue = DispatchQueue(label: "HttpClientBgQueue")

    func get(_ path: String) -> AnyPublisher<Data, Error> {
        guard let url = URL(string: path) else {
            return Fail(error: "HttpStandardService: get: invalid url: \(path)")
                .eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue(self.env.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.httpMethod = "GET"

        return self.session.dataTaskPublisher(for: request)
            .tryCatch { error in
                // A delayed retry (total 3 attemps spread 1-5 sec at random)
                return self.session.dataTaskPublisher(for: request)
                    .delay(for: DispatchQueue.SchedulerTimeType.Stride(integerLiteral: Int.random(in: 1..<5)), scheduler: self.bgQueue)
                    .retry(2)
            }
            .tryMap { response -> Data in
                guard let r = response.response as? HTTPURLResponse else {
                    throw "no response"
                }

                guard r.statusCode == 200 else {
                    throw NetworkError.http(r.statusCode)
                }

                return response.data
            }
            .eraseToAnyPublisher()
    }

    // TODO: should post/put also repeat on fail?
    func postOrPut(_ path: String, method: String, payload: Encodable?) -> AnyPublisher<Data, Error> {
        guard let url = URL(string: path) else {
            return Fail(error: "HttpStandardService: post: invalid url: \(path)")
                .eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue(self.env.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.httpMethod = method

        if payload != nil {
            guard let payloadEncoded = payload?.toJsonData() else {
                return Fail(error: "HttpStandardService: could not encode payload")
                    .eraseToAnyPublisher()
            }
            request.httpBody = payloadEncoded
        }

        return self.session.dataTaskPublisher(for: request)
            .tryMap { response -> Data in
                guard let r = response.response as? HTTPURLResponse else {
                    throw "no response"
                }

                guard r.statusCode == 200 else {
                    throw NetworkError.http(r.statusCode)
                }

                return response.data
            }
            .eraseToAnyPublisher()
    }

}
