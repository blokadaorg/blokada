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

struct GatewaySelection {
    let gateway: Gateway?
}

class GatewayRepo: Startable {

    var gatewaysHot: AnyPublisher<[Gateway], Never> {
        writeGateways.compactMap { $0 }.eraseToAnyPublisher()
    }

    var selectedHot: AnyPublisher<GatewaySelection, Never> {
        writeSelected.compactMap { $0 }
        .removeDuplicates { a, b in a.gateway == b.gateway }
        .eraseToAnyPublisher()
    }

    private lazy var persistence = Services.persistenceLocal
    private lazy var api = Services.apiForCurrentUser

    fileprivate let writeGateways = CurrentValueSubject<[Gateway]?, Never>(nil)
    fileprivate let writeSelected = CurrentValueSubject<GatewaySelection?, Never>(nil)

    fileprivate let loadGatewaysT = SimpleTasker<Ignored>("loadGateways")

    private let decoder = blockaDecoder
    private let encoder = blockaEncoder

    private var cancellables = Set<AnyCancellable>()

    func start() {
        onLoadGateways()
        onGatewaySelectionChanged_Persist()
        loadGatewaySelectionOnStart()
    }

    func setGatewaySelection(_ gw: GatewayId?) {
        if let gw = gw {
            gatewaysHot.first()
            .map { it in
                let matchingGateway = it.first { $0.public_key == gw }
                if matchingGateway == nil {
                    BlockaLogger.e("GatewayRepo", "Unknown Gateway ID, ignoring")
                }
                return matchingGateway
            }
            .sink(onValue: { it in
                self.writeSelected.send(GatewaySelection(gateway: it))
            })
            // TODO: make sure that these one-off cancellables are fine to be added indefinitely
            .store(in: &cancellables)
        } else {
            writeSelected.send(GatewaySelection(gateway: nil))
        }
    }

    func refreshGateways() -> AnyPublisher<Ignored, Error> {
        return loadGatewaysT.send()
    }

    private func loadGatewaySelectionOnStart() {
        loadGwSelectionFromPers()
        .sink(onValue: { it in self.writeSelected.send(it) })
        .store(in: &cancellables)
    }

    private func onLoadGateways() {
        loadGatewaysT.setTask { _ in Just(true)
            .flatMap { _ in self.api.client.getGateways() }
            .map { it in self.writeGateways.send(it) }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onGatewaySelectionChanged_Persist() {
        selectedHot
        .flatMap { it in
            self.saveGwSelectionToPers(it)
        }
        .sink()
        .store(in: &cancellables)
    }

    private func loadGwSelectionFromPers() -> AnyPublisher<GatewaySelection, Error> {
        return persistence.getString(forKey: "gateway")
        .tryMap { it -> Data in
            guard let it = it.data(using: .utf8) else {
                throw "gateways: failed reading persisted account data"
            }

            return it
        }
        .decode(type: Gateway.self, decoder: self.decoder)
        .map { it in GatewaySelection(gateway: it) }
        .tryCatch { err -> AnyPublisher<GatewaySelection, Error> in
            if err as? CommonError == CommonError.emptyResult {
                return Just(GatewaySelection(gateway: nil))
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            }
            throw err
        }
        .eraseToAnyPublisher()
    }

    private func saveGwSelectionToPers(_ selection: GatewaySelection) -> AnyPublisher<Ignored, Error> {
        if let gw = selection.gateway {
            return Just(gw).encode(encoder: self.encoder)
            .tryMap { it -> String in
                guard let it = String(data: it, encoding: .utf8) else {
                    throw "gateways: could not encode json data to string"
                }
                return it
            }
            .flatMap { it in
                return self.persistence.setString(it, forKey: "gateway")
            }
            .eraseToAnyPublisher()
        } else {
            return persistence.delete(forKey: "gateway")
        }
    }

}
