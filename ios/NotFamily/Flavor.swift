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
import Flutter

class Flavor {
    
    let CHANNEL_NAME = "org.blokada/flavor"

    func attach(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: CHANNEL_NAME,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            result(self.getFlavor())
        })
    }
    
    func getFlavor() -> String {
        return "notfamily"
    }
}
