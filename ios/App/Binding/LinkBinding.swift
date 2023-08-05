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
import Combine

class LinkBinding: LinkOps {
    let links = CurrentValueSubject<[LinkId : String], Never>([:])

    @Injected(\.flutter) private var flutter

    init() {
        LinkOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doLinksChanged(links: [Link], completion: @escaping (Result<Void, Error>) -> Void) {
        self.links.send(transformLinks(links))
        completion(.success(()))
    }

    func transformLinks(_ links: [Link]) -> [LinkId: String] {
        var transformedLinks = [LinkId: String]()
        for link in links {
            transformedLinks[link.id] = link.url
        }
        return transformedLinks
    }
}

extension Container {
    var link: Factory<LinkBinding> {
        self { LinkBinding() }.singleton
    }
}
