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

class VpnService {

    static let shared = VpnService()

    private let network = NetworkService.shared
    private let engine = EngineService.shared
    private let log = Logger("Vpn")

    private init() {
        // Singleton
    }

    func changeGateway(lease: Lease, gateway: Gateway, done: @escaping Callback<String>) {
        onBackground {
            self.network.queryStatus { error, status in
                self.network.updateConfig(lease: lease, gateway: gateway) { _, _ in
                    if status?.active ?? false {
                        self.network.changeGateway(lease: lease, gateway: gateway, done: done)
                    } else {
                        self.network.startTunnel(done: { error, _ in done(error, "") })
                    }
                }
            }
        }
    }

    func disconnect(done: @escaping Callback<String>) {
        onBackground {
            self.network.updateConfig(lease: nil, gateway: nil) { _, _ in
                self.network.disconnect(done: done)
            }
        }
    }

    func generateKeypair() -> (String, String) {
        return engine.generateKeypair()
    }

    func turnOffEverything(done: @escaping Callback<Void>) {
        onBackground {
           self.log.v("Turning off everything")
            self.network.queryStatus { error, status in onMain {
                   guard let status = status else {
                       return done(error, nil)
                   }

                if status.active {
                    self.network.stopTunnel { error, _ in
                        self.network.updateConfig(lease: nil, gateway: nil) { error, _ in
                            onMain {
                                done(error, nil)
                            }
                        }
                    }
                } else {
                    done(nil, nil)
                }
            }}
       }
    }

    func restartTunnel(done: @escaping Callback<Void>) {
       onBackground {
           self.network.queryStatus { error, status in
            self.network.updateConfig(lease: Config.shared.lease(), gateway: Config.shared.gateway()) { _, _ in
                    if status?.active ?? false {
                        self.log.v("Restarting tunnel")
                        self.network.stopTunnel { error, _ in
                            if error == nil {
                                self.network.startTunnel(done: done)
                            } else {
                                self.log.e("Failed restarting tunnel".cause(error))
                            }
                        }
                    }
                }
            }
       }
   }
}
