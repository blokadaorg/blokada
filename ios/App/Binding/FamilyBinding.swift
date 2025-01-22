//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2025 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import Combine

// TODO: this should be included only in Family targets but AppDelegate needs refactor
class FamilyBinding: FamilyOps {
    let shareUrl = CurrentValueSubject<URL?, Never>(nil)

    @Injected(\.flutter) private var flutter

    init() {
        FamilyOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doShareUrl(url: String, completion: @escaping (Result<Void, any Error>) -> Void) {
        if let url = URL(string: url) {
            shareUrl.send(url)
            return completion(.success(()))
        } else {
            return completion(.failure("Incorrect url"))
        }
    }
}

extension Container {
    var family: Factory<FamilyBinding> {
        self { FamilyBinding() }.singleton
    }
}
