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

class CustomViewModel: ObservableObject {
    @Injected(\.custom) private var custom
    @Injected(\.commands) private var commands

    @Published var whitelist = [String]()
    @Published var blacklist = [String]()

    init() {
        custom.onAllowed = { it in
            self.whitelist = it
            self.objectWillChange.send()
        }

        custom.onDenied = { it in
            self.blacklist = it
            self.objectWillChange.send()
        }
    }

    func mocked() {
        blacklist = ["example.com", "example.com", "example3.com"]
        whitelist = ["ok1.com", "ok2.com", "ok3.com"]
    }

    func allow(_ entry: String) {
        commands.execute(.allow, entry)
    }

    func deny(_ entry: String) {
        commands.execute(.deny, entry)
    }

    func delete(_ entry: String) {
        commands.execute(.delete, entry)
    }
}
