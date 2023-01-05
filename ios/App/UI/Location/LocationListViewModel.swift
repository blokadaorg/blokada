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
import Combine

class LocationListViewModel: ObservableObject {

    private lazy var gatewayRepo = Repos.gatewayRepo
    private lazy var plusRepo = Repos.plusRepo

    private var cancellables = Set<AnyCancellable>()

    @Published var items = [String: [LocationViewModel]]()

    init() {
        onGatewaysChanged()
    }

    private func onGatewaysChanged() {
        Publishers.CombineLatest(
            gatewayRepo.gatewaysHot,
            gatewayRepo.selectedHot
        )
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            let (gateways, selection) = it
            let vms = gateways.sorted { $0.location < $1.location }
            .map { gateway in
                LocationViewModel(
                    gateway: gateway,
                    selectedGateway: selection.gateway
                )
            }

            self.items = Dictionary(
                grouping: vms,
                by: { $0.gateway.region.components(separatedBy: "-")[0]  }
            )
        })
        .store(in: &cancellables)
    }

    func loadGateways(done: @escaping Ok<Void>) {
        items = Dictionary()
        gatewayRepo.refreshGateways()
        .receive(on: RunLoop.main)
        .sink(
            onFailure: { _ in done(()) },
            onSuccess: { done(()) }
        )
        .store(in: &cancellables)
    }

    func changeLocation(_ item: LocationViewModel) {
        plusRepo.newPlus(item.gateway.public_key)
    }

}
