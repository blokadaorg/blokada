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

// This file defines services configuration for real build.
// Another definition for Mocked builds is in ServiceMock dir.

var Services = ServicesSingleton()

class ServicesSingleton {

    fileprivate init() {}

    lazy var systemNav = SystemNavService()
    lazy var dialog = DialogService()
    lazy var netx: NetxServiceIn = NetxServiceMock()
    lazy var quickActions = QuickActionsService()
}

func resetServices() {
    Services = ServicesSingleton()
}
