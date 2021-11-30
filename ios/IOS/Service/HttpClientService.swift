//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Combine

class HttpClientService {
    func get(url: String) -> AnyPublisher<Data, Error> {
        guard let url = URL(string: url) else {
            return Fail(error: "get: Could not parse URL: \(url)").eraseToAnyPublisher()
        }

        return URLSession.shared.dataTaskPublisher(for: url).tryMap { response -> Data in
            guard let r = response.response as? HTTPURLResponse else {
                throw "no response"
            }

            guard r.statusCode == 200 else {
                throw "response \(r.statusCode)"
            }

            return response.data
        }
        .mapError { "get: \($0)" }
        .eraseToAnyPublisher()
    }
}
