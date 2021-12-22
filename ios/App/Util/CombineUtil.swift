//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine

// Used as a non-meaningful return type for publishers, to avoid using Void as it brings
// some problems in some cases.
typealias Ignored = Bool

extension Publisher {

    func sink(
        onValue: @escaping (Self.Output) -> Void = { _ in },
        onFailure: @escaping (Self.Failure) -> Void = { _ in },
        onSuccess: @escaping () -> Void = {}
    ) -> AnyCancellable {
        return self.sink(receiveCompletion: { completion in
            switch (completion) {
            case .failure(let err):
                onFailure(err)
                break
            case .finished:
                onSuccess()
                break
            }
            
        }, receiveValue: { it in onValue(it) })
    }

//    func toAny() -> AnyPublisher<Self.Output, Error> {
//        return self.setFailureType(to: Error.self).eraseToAnyPublisher()
//    }
}
