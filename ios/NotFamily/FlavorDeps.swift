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

class FlavorDeps {
    @Injected(\.plusKeypair) private var plusKeypair
    @Injected(\.plusVpn) private var plusVpn
}
