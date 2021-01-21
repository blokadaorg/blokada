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

class LocationListViewModel: ObservableObject {

    @Published var items = [String: [LocationViewModel]]()

    private let api = BlockaApiService.shared
    private let sharedActions = SharedActionsService.shared

    func loadGateways(done: @escaping Ok<Void>) {
        self.items = Dictionary()

        self.api.getGateways { error, gateways in
            onMain {
                guard error == nil else {
                    return done(())
                }
                let vms = gateways!.sorted { $0.location < $1.location }
                .map { gateway in
                    LocationViewModel(gateway: gateway, selectedGateway: self.selectedGateway())
                }

                self.items = Dictionary(grouping: vms, by: { $0.gateway.region.components(separatedBy: "-")[0]  })

                return done(())
            }
        }
    }

    func changeLocation(_ item: LocationViewModel) {
        sharedActions.changeGateway(item.gateway)
    }

    private func selectedGateway() -> Gateway? {
        if Config.shared.hasLease() && Config.shared.hasGateway() {
            return Config.shared.gateway()
        } else {
            return nil
        }
    }
}
