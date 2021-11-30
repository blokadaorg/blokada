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

extension Publisher {

    func sink(
        onValue: @escaping (Self.Output) -> Void = { _ in },
        onFailure: @escaping (Self.Failure) -> Void = { _ in },
        onFinished: @escaping () -> Void = {}
    ) -> AnyCancellable {
        return self.sink(receiveCompletion: { completion in
            switch (completion) {
            case .failure(let err):
                onFailure(err)
                break
            case .finished:
                onFinished()
                break
            }
            
        }, receiveValue: { it in onValue(it) })
    }

//    func toAny() -> AnyPublisher<Self.Output, Error> {
//        return self.setFailureType(to: Error.self).eraseToAnyPublisher()
//    }
}
