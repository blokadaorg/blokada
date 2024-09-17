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
import FlutterPluginRegistrant

extension FlutterError: Error {}

class Flutter {
    lazy var flutterEngine = FlutterEngine(name: "common")
    var isFlavorFamily = false

    init() {
        flutterEngine.run()
        GeneratedPluginRegistrant.register(with: flutterEngine)
        let flavor = Flavor()
        flavor.attach(messenger: flutterEngine.binaryMessenger)
        isFlavorFamily = flavor.getFlavor() == "family"
    }

    func getMessenger() -> FlutterBinaryMessenger {
        return flutterEngine.binaryMessenger
    }

    func getEngine() -> FlutterEngine {
        return flutterEngine
    }
}

extension Container {
    var flutter: Factory<Flutter> {
        self { Flutter() }.singleton
    }
}
