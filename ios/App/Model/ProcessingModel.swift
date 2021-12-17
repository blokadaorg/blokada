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

struct ComponentError: Error {
    let component: String
    let error: Error
    let major: Bool
}

struct ComponentOngoing: CustomStringConvertible {
    let component: String
    let ongoing: Bool

    public var description: String { return "\(component)" }
}

extension ComponentOngoing: Equatable {
    static func == (lhs: ComponentOngoing, rhs: ComponentOngoing) -> Bool {
        return
            lhs.component == rhs.component &&
            lhs.ongoing == rhs.ongoing
    }
}

extension ComponentOngoing: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(component)
        hasher.combine(ongoing)
    }
}
