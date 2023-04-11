//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Flutter
import Factory

class Flutter {
    lazy var flutterEngine = FlutterEngine(name: "common")

    private lazy var service = FlutterService()

    init() {
        flutterEngine.run()
    }

    func getMessenger() -> FlutterBinaryMessenger {
        return flutterEngine.binaryMessenger
    }

    func getEngine() -> FlutterEngine {
        return flutterEngine
    }

    func setupChannels(controller: FlutterViewController) {
        service.setupChannels(controller: controller)
    }
}

extension Container {
    var flutter: Factory<Flutter> {
        self { Flutter() }.singleton
    }
}
