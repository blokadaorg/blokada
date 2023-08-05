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
import Combine
import Factory

class FamilyBinding: FamilyOps {
    
    @Injected(\.flutter) private var flutter

    var familyLinkTemplate: String = ""

    init() {
        FamilyOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doFamilyLinkTemplateChanged(linkTemplate: String, completion: @escaping (Result<Void, Error>) -> Void) {
        familyLinkTemplate = linkTemplate
        completion(.success(()))
    }
}

extension Container {
    var family: Factory<FamilyBinding> {
        self { FamilyBinding() }.singleton
    }
}
