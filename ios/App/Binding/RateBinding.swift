//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import SwiftUI
import StoreKit

class RateBinding: RateOps {
    @Injected(\.flutter) private var flutter

    init() {
        RateOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doShowRateDialog(completion: @escaping (Result<Void, Error>) -> Void) {
        requestReview()
        completion(.success(()))
    }
}

private func requestReview() {
    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        SKStoreReviewController.requestReview(in: scene)
    }
}

extension Container {
    var rate: Factory<RateBinding> {
        self { RateBinding() }.singleton
    }
}
