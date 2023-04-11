//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Factory
import Combine

class HttpBinding: HttpOps {
    @Injected(\.flutter) private var flutter
    @Injected(\.env) private var env

    private lazy var service = Services.httpProtected
    private lazy var netx = Services.netx
    private var session: URLSession

    fileprivate let netxState = CurrentValueSubject<VpnStatus, Never>(VpnStatus.unknown)
    private var cancellables = Set<AnyCancellable>()

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(15)
        configuration.timeoutIntervalForResource = TimeInterval(15)
        session = URLSession(configuration: configuration)

        HttpOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
        onVpnStatus()
    }

    func doGet(url: String, completion: @escaping (Result<String, Error>) -> Void) {
        if netxState.value == .activated || netxState.value == .reconfiguring {
            BlockaLogger.v("HttpBinding", "Making protected request")
            netx.makeProtectedRequest(url: url, method: "GET", body: "")
            .sink(
                onValue: { it in completion(.success(it)) },
                onFailure: { err in completion(.failure(err))}
            )
            .store(in: &cancellables)
            return
        }

        guard let url = URL(string: url) else {
            return completion(Result.failure("invalid url"))
        }

        var request = URLRequest(url: url)
        request.setValue(self.env.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.httpMethod = "GET"

        let task = self.session.dataTask(with: request) { payload, response, error in
            if let e = error {
                return completion(Result.failure(e))
            }

            guard let r = response as? HTTPURLResponse else {
                return completion(Result.failure("no response"))
            }

            guard r.statusCode == 200 else {
                return completion(Result.failure("code:\(r.statusCode)"))
            }

            guard let payload = payload else {
                return completion(Result.success(""))
            }

            return completion(Result.success(String(decoding: payload, as: UTF8.self)))
        }
        task.resume()
    }
    
    func doRequest(url: String, payload: String?, type: String,
                   completion: @escaping (Result<String, Error>) -> Void) {
        if netxState.value == .activated || netxState.value == .reconfiguring {
            BlockaLogger.v("HttpBinding", "Making protected request")
            netx.makeProtectedRequest(url: url, method: type.uppercased(), body: payload ?? "")
            .sink(
                onValue: { it in completion(.success(it)) },
                onFailure: { err in completion(.failure(err))}
            )
            .store(in: &cancellables)
            return
        }

        guard let url = URL(string: url) else {
            return completion(Result.failure("invalid url"))
        }

        var request = URLRequest(url: url)
        request.setValue(self.env.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.httpMethod = type.uppercased()

        if payload != nil {
            request.httpBody = payload?.data(using: .utf8)
        }

        let task = self.session.dataTask(with: request) { payload, response, error in
            if let e = error {
                return completion(Result.failure(e))
            }

            guard let r = response as? HTTPURLResponse else {
                return completion(Result.failure("no response"))
            }

            guard r.statusCode == 200 else {
                return completion(Result.failure("code:\(r.statusCode)"))
            }

            guard let payload = payload else {
                return completion(Result.success(""))
            }

            return completion(Result.success(String(decoding: payload, as: UTF8.self)))
        }
        task.resume()
    }

    private func onVpnStatus() {
        netx.getStatePublisher()
        .sink(onValue: { it in self.netxState.send(it) })
        .store(in: &cancellables)
    }
}

extension Container {
    var http: Factory<HttpBinding> {
        self { HttpBinding() }.singleton
    }
}
