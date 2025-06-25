//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2025 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//


import Foundation
import Factory
import Combine
import Flutter

class SafariBinding: SafariOps {

    @Injected(\.flutter) private var flutter

    var mockActive = 0

    init() {
        SafariOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doGetStateOfContentFilter(completion: @escaping (Result<Bool, any Error>) -> Void) {
        // TODO (for now first calls false, then true)
        completion(Result.success(mockActive > 10))
        mockActive += 1
    }

    func doUpdateContentFilterRules(
        filtering: Bool,
        completion: @escaping (Result<Void, any Error>) -> Void
    ) {
        // TODO
        completion(Result.success(()))
    }

    func doOpenPermsFlowForYoutube(completion: @escaping (Result<Void, any Error>) -> Void) {
        let url = URL(string: "https://go.blokada.org/howto/safari-extension")!
        UIApplication.shared.open(url)
        completion(Result.success(()))
    }

    func doOpenPermsFlowForContentFilter(completion: @escaping (Result<Void, any Error>) -> Void) {
        // TODO
        //let url = URL(string: "https://go.blokada.org/howto/safari-extension")!
        //UIApplication.shared.open(url)
        completion(Result.success(()))
    }
}

extension Container {
    var safari: Factory<SafariBinding> {
        self { SafariBinding() }.singleton
    }
}