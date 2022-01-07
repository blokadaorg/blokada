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
import NetworkExtension

class NetworkService {

    static let shared = NetworkService()

    private let log = Logger("Network")
    private let config = Config.shared

    var httpClient: OpaquePointer?
    private let configurationFilteringOnly = "No Server"

    var onStatusChanged = { (status: NetworkStatus) in }

    private var startingCallback = Atomic<Callback<Void>?>(nil)
    private var stoppingCallback = Atomic<Callback<Void>?>(nil)
    private var started = Atomic<Bool>(false)
    private var attemptId = Atomic<Int>(0)
    private var attempts = Atomic<Int>(0)

    func foreground() {
        onBackground {
            self.log.v("foreground, creating httpclient")
            self.httpClient = api_new(10, Services.http.userAgent())
        }
    }

    func background() {
        onBackground {
            self.log.v("background, free httpclient")
            api_free(self.httpClient)
            self.httpClient = nil
        }
    }

    func applyGateway(done: @escaping Callback<String>) {
        onBackground {
//            guard self.config.hasLease() else {
//                return done("syncGateway: No lease set", nil)
//            }
//
//            let lease = self.config.lease()!
//
//            guard let gateway = self.config.gateway() else {
//                return done("syncGateway: No gateway set", nil)
//            }
//
//            let connect = [
//                NetworkCommand.connect.rawValue,
//                Config.shared.privateKey(),
//                lease.gateway_id,
//                gateway.ipv4,
//                gateway.ipv6,
//                String(gateway.port),
//                lease.vip4,
//                lease.vip6,
//                self.getUserDnsIp(Config.shared.deviceTag())
//            ].joined(separator: " ")
//            self.sendMessage(msg: connect) { error, _ in
//                guard error == nil else {
//                    return onMain {
//                        self.onStatusChanged(NetworkStatus(active: true, inProgress: false, gatewayId: nil, pauseSeconds: 0))
//                        done(error, nil)
//                    }
//                }
//
//                self.onStatusChanged(NetworkStatus(active: true, inProgress: false, gatewayId: gateway.public_key, pauseSeconds: 0))
//                done(nil, nil)
//            }
        }
    }

    func directRequest(url: String, method: String, body: String, done: @escaping Callback<String>) {
        onBackground {
            guard let httpClient = self.httpClient else {
                return done("httpClient was not initialized", nil)
            }

            let result = api_request(httpClient, method, url, body)
            defer { api_response_free(result) }
            if let res = result {
                if let error = res.pointee.error {
                    let err = String(cString: error)
                    return onMain { done(err, nil) }
                }

                if res.pointee.code != 200 {
                    return onMain { done(NetworkError.http(Int(res.pointee.code)), nil) }
                }

                let responseBody = String(cString: res.pointee.body)
                onMain { done(nil, responseBody) }
            } else {
                return onMain { done("No result", nil) }
            }
        }
    }

    func disconnect(done: @escaping Callback<String>) {
        onBackground {
//            self.sendMessage(msg: NetworkCommand.disconnect.rawValue) { error, _ in
//                self.onStatusChanged(NetworkStatus(active: true, inProgress: false, gatewayId: nil, pauseSeconds: 0))
//                done(error, nil)
//            }
        }
    }

    func pause(seconds: Int, done: @escaping Callback<String>) {
        onBackground {
//            let command = ["pause", String(seconds)].joined(separator: " ")
//            self.sendMessage(msg: command, done: done)
        }
    }


}
