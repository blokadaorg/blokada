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

// HttpRepo makes HTTP requests through either a standard client, or protected client.
// It chooses one or another based on whether NETX is running or not.
// If it is, requests needs to be protected (make outside) in case tunnel expires.
class HttpRepo: Startable {

    private lazy var standard = Services.httpStandard
    private lazy var protected = Services.httpProtected

    private lazy var netxRepo = Repos.netxRepo

    func get(_ path: String) -> AnyPublisher<Data, Error> {
        return netxRepo.netxStateHot.filter { !$0.inProgress }.first()
        .flatMap { it -> AnyPublisher<Data, Error> in
            if it.active || it.pauseSeconds > 0 {
                return self.protected.get(path)
            } else {
                return self.standard.get(path)
            }
        }
        .eraseToAnyPublisher()
    }

    func post(_ path: String, payload: Encodable?) -> AnyPublisher<Data, Error> {
        return netxRepo.netxStateHot.filter { !$0.inProgress }.first()
        .flatMap { it -> AnyPublisher<Data, Error> in
            if it.active || it.pauseSeconds > 0 {
                return self.protected.postOrPut(path, method: "POST", payload: payload)
            } else {
                return self.standard.postOrPut(path, method: "POST", payload: payload)
            }
        }
        .eraseToAnyPublisher()
    }

    func put(_ path: String, payload: Encodable?) -> AnyPublisher<Data, Error> {
        return netxRepo.netxStateHot.filter { !$0.inProgress }.first()
        .flatMap { it -> AnyPublisher<Data, Error> in
            if it.active || it.pauseSeconds > 0 {
                return self.protected.postOrPut(path, method: "PUT", payload: payload)
            } else {
                return self.standard.postOrPut(path, method: "PUT", payload: payload)
            }
        }
        .eraseToAnyPublisher()
    }

    func delete(_ path: String, payload: Encodable?) -> AnyPublisher<Data, Error> {
        return netxRepo.netxStateHot.filter { !$0.inProgress }.first()
        .flatMap { it -> AnyPublisher<Data, Error> in
            if it.active || it.pauseSeconds > 0 {
                return self.protected.postOrPut(path, method: "DELETE", payload: payload)
            } else {
                return self.standard.postOrPut(path, method: "DELETE", payload: payload)
            }
        }
        .eraseToAnyPublisher()
    }

    func start() {}
}
