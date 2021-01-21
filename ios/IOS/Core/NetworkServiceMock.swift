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

class NetworkService {

    static let shared = NetworkService()

    var onStatusChanged = { (status: NetworkStatus) in }

    private init() {
        // singleton
    }

    private var status = Atomic<NetworkStatus>(NetworkStatus(
        active: false,
        inProgress: false,
        gatewayId: nil,
        pauseSeconds: 0
    ))

    func updateConfig(lease: Lease?, gateway: Gateway?, done: @escaping Callback<Void>) {
        done(nil, nil)
    }

    func sendMessage(msg: String, skipReady: Bool = false, done: @escaping Callback<String>) {
        onBackground {
            let params = msg.components(separatedBy: " ")
            switch params[0] {
            case NetworkCommand.connect.rawValue:
                self.handleConnect(msg, done)
            case NetworkCommand.disconnect.rawValue:
                self.handleDisconnect(done)
            case NetworkCommand.request.rawValue:
                self.handleRequest(msg, done)
            default:
                onMain { done("non-mocked command: \(params[0])", nil) }
            }
        }
    }

    func createVpnProfile(done: @escaping Callback<Void>) {
        onBackground {
            onMain { done(nil, nil) }
        }
    }

    func startTunnel(done: @escaping Callback<Void>) {
        onBackground {
            sleep(1)
            self.status.value = NetworkStatus(active: true, inProgress: false, gatewayId: nil, pauseSeconds: 0)
            onMain { self.onStatusChanged(self.status.value) }
            onMain { done(nil, nil) }
        }
    }

    func stopTunnel(done: @escaping Callback<Void>) {
        onBackground {
            sleep(1)
            self.status.value = NetworkStatus(active: false, inProgress: false, gatewayId: nil, pauseSeconds: 0)
            onMain { self.onStatusChanged(self.status.value) }
            onMain { done(nil, nil) }
        }
    }

    func queryStatus(done: @escaping Callback<NetworkStatus>) {
        onBackground {
            onMain { done(nil, self.status.value) }
        }
    }

    func changeGateway(lease: Lease, gateway: Gateway, done: @escaping Callback<String>) {
        onBackground {
            sleep(1)
            onMain {
                self.status.value = NetworkStatus(active: true, inProgress: false, gatewayId: gateway.public_key, pauseSeconds: 0)
                self.onStatusChanged(self.status.value)
                done(nil, "")
            }
        }
    }

    func disconnect(done: @escaping Callback<String>) {
        onBackground {
            sleep(1)
            onMain {
                self.status.value = NetworkStatus(active: true, inProgress: false, gatewayId: nil, pauseSeconds: 0)
                self.onStatusChanged(self.status.value)
                done(nil, "")
            }
        }
    }

    func pause(seconds: Int, done: @escaping Callback<String>) {
        onBackground {
            onMain { done(nil, "") }
        }
    }

    func restartTunnel(done: @escaping Callback<Void>) {
        onBackground {
            done(nil, nil)
        }
    }

    private func handleConnect(_ msg: String, _ done: @escaping Callback<String>) {
        sleep(1)
        let params = msg.components(separatedBy: " ")
        self.status.value = NetworkStatus(active: true, inProgress: false, gatewayId: params[2], pauseSeconds: 0)
        onMain { done(nil, "") }
    }

    private func handleDisconnect(_ done: @escaping Callback<String>) {
        sleep(1)
        self.status.value = NetworkStatus(active: true, inProgress: false, gatewayId: nil, pauseSeconds: 0)
        onMain { done(nil, "") }
    }

    private var active = false

    private func handleRequest(_ msg: String, _ done: @escaping Callback<String>) {
        sleep(1)
        let params = msg.components(separatedBy: " ")
        let url = params[1]
        let method = params[2]
        Logger.v("Mock", "Mocking request: \(url)")

        if url.contains("/account") {
            onMain { done(nil,
                self.active ?
                    """
                    {"account":{"id":"mockedmocked","active_until":"2069-03-15T11:38:38.48383Z","active":true,"payment_source":"stellar"}}
                    """
                :
                    """
                    {"account":{"id":"mockedmocked","active_until":"2009-03-15T11:38:38.48383Z","active":false,"payment_source":"stellar"}}
                    """
            ) }
        } else if url.contains("/gateway") {
            onMain { done(nil, """
                {"gateways":[{"public_key":"aWgVkVE22ybHrPTP5d9fPOKI6dArQykGsVzb+T1aJA4=","region":"europe-north1","location":"stockholm","resource_usage_percent":12,"ipv4":"46.227.65.28","ipv6":"2a03:8600:0:110::28","port":51820,"expires":"2020-04-16T17:09:17.700686Z","tags":null},{"public_key":"gnUtzlyaPJU+K2bbVBcdV9VmNtltjncLycxxl/gbN00=","region":"europe-west1","location":"paris","resource_usage_percent":6,"ipv4":"45.152.181.242","ipv6":"2001:ac8:25:a3::2","port":51820,"expires":"2020-04-16T17:10:19.803432Z","tags":null},{"public_key":"138GYchUe81EwLE5QlLTrlhLgHS2YWDMQaCC3l3amzs=","region":"europe-west2","location":"london","resource_usage_percent":11,"ipv4":"193.9.113.86","ipv6":"2001:ac8:31:fb::","port":51820,"expires":"2020-04-16T17:11:12.726083Z","tags":null},{"public_key":"sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=","region":"us-east1","location":"new-york","resource_usage_percent":29,"ipv4":"45.152.180.138","ipv6":"2a0d:5600:24:df::","port":51820,"expires":"2020-04-16T17:12:18.868987Z","tags":null},{"public_key":"9EkWecXwOvJQ0dMt1L4wFIDuJm354PZVySpQf6W3IxY=","region":"asia-northeast1","location":"tokyo","resource_usage_percent":4,"ipv4":"185.242.4.142","ipv6":"2001:ac8:40:a::","port":51820,"expires":"2020-04-16T17:13:14.188839Z","tags":null},{"public_key":"9EkWecXwOvJQ0dMt1L4wFIDuJm354PZVySpQf6W3IxZ=","region":"asia-northeast1","location":"tokyo2","resource_usage_percent":1,"ipv4":"185.242.4.143","ipv6":"2001:ac8:40:b::","port":51820,"expires":"2020-04-16T17:13:14.188839Z","tags":null},{"public_key":"9EkWecXwOvJQ0dMt1L4wFIDuJm354PZVySpQf6W3IxX=","region":"asia-northeast1","location":"tokyo-drift","resource_usage_percent":0,"ipv4":"185.242.4.144","ipv6":"2001:ac8:40:c::","port":51820,"expires":"2020-04-16T17:13:14.188839Z","tags":null},{"public_key":"H1TTLm88Zm+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=","region":"europe-west1","location":"frankfurt","resource_usage_percent":33,"ipv4":"45.87.212.230","ipv6":"2001:ac8:20:e7::","port":51820,"expires":"2020-04-16T17:14:11.666905Z","tags":null},{"public_key":"H1TTLm38Zm+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=","region":"europe-west1","location":"amsterdam","resource_usage_percent":33,"ipv4":"45.87.212.230","ipv6":"2001:ac8:20:e7::","port":51820,"expires":"2020-04-16T17:14:11.666905Z","tags":null},{"public_key":"H1TTLm884m+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=","region":"europe-asia1","location":"dubai","resource_usage_percent":33,"ipv4":"45.87.212.230","ipv6":"2001:ac8:20:e7::","port":51820,"expires":"2020-04-16T17:14:11.666905Z","tags":null},{"public_key":"H1TTL4884m+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=","region":"europe-asia1","location":"china","resource_usage_percent":33,"ipv4":"45.87.212.230","ipv6":"2001:ac8:20:e7::","port":51820,"expires":"2020-04-16T17:14:11.666905Z","tags":null}]}
                """) }
        } else if url.contains("/lease") {
            onMain { done(nil, """
                {"lease": {"account_id":"mockedmocked","public_key":"meetGdjSweb+JIoXF0JRJPWZ+srMQrfE9P2vVCxlfz0=","gateway_id":"138GYchUe81EwLE5QlLTrlhLgHS2YWDMQaCC3l3amzs=","expires":"2069-04-16T16:28:38Z","vip4":"10.143.0.225","vip6":"fdad:b10c:a::a8f:e1","alias":"Mocked iPhone"}}
                """) }
        } else if url.contains("/apple/checkout") {
            onMain {
                Logger.v("Mock", "Setting mocked account as active")
                self.active = true
                done(nil,
                     """
                     {"account":{"id":"mockedmocked","active_until":"2069-03-15T11:38:38.48383Z","active":true,"payment_source":"stellar"}}
                     """
                )
            }
        } else {
            Logger.e("Mock", "Unsupported request")
            onMain { done(nil, "") }
        }
    }

    func directRequest(url: String, method: String, body: String, done: @escaping Callback<String>) {
        onMain { done("mock does not support directRequest", nil) }
    }
}
