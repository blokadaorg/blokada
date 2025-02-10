//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2024 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import UIKit

class UrlBinding: UrlLauncherApi {

    @Injected(\.flutter) private var flutter

    init() {
        UrlLauncherApiSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }
    
    func canLaunchUrl(url: String) throws -> LaunchResult {
        // let canOpen = UIApplication.shared.canOpenURL(url)
        return .success
    }

    func launchUrl(url: String, universalLinksOnly: Bool, completion: @escaping (Result<LaunchResult, any Error>) -> Void) {
        let u = URL(string: url)!
        UIApplication.shared.open(u, options: [:]) { success in
            completion(.success(.success))
        }
    }

    func openUrlInSafariViewController(url: String, completion: @escaping (Result<InAppLoadResult, any Error>) -> Void) {
        // Not used
        completion(.failure("not implemented"))
    }

    func closeSafariViewController() throws {
        // Not used
    }
}

extension Container {
    var url: Factory<UrlBinding> {
        self { UrlBinding() }.singleton
    }
}
