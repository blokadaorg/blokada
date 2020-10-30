//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
                self.network.updateConfig(lease: lease, gateway: gateway, useBlockaDnsInPlusMode: Config.shared.useBlockaDnsInPlusMode()) { _, _ in
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
            self.network.updateConfig(lease: nil, gateway: nil, useBlockaDnsInPlusMode: Config.shared.useBlockaDnsInPlusMode()) { _, _ in
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
                        self.network.updateConfig(lease: nil, gateway: nil, useBlockaDnsInPlusMode: Config.shared.useBlockaDnsInPlusMode()) { error, _ in
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
            self.network.updateConfig(lease: Config.shared.lease(), gateway: Config.shared.gateway(), useBlockaDnsInPlusMode: Config.shared.useBlockaDnsInPlusMode()) { _, _ in
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
