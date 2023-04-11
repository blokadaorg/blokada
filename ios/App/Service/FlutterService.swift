//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Flutter
import Combine
import Factory

class FlutterService {
    @Injected(\.app) private var app
    @Injected(\.account) private var account
    @Injected(\.stage) private var stage

    private lazy var sheetRepo = stage

    var shareCounter: Int = 0

    func setupChannels(controller: FlutterViewController) {
        // Log from flutter (to save in file)
        let onLog = FlutterMethodChannel(name: "log",
            binaryMessenger: controller.binaryMessenger)
        onLog.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            let line = call.arguments as? String
            if let l = line {
                if call.method == "e" {
                    BlockaLogger.e("Common", l)
                } else {
                    BlockaLogger.v("Common", l)
                }
            }
        })

        // Share counter
//        let share = FlutterMethodChannel(name: "share",
//            binaryMessenger: controller.binaryMessenger)
//        share.setMethodCallHandler({
//            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
//            let counter = call.arguments as? Int
//            if let c = counter {
//                self.shareCounter = c
//                self.sheetRepo.stage.showModal(.ShareAdsCounter)
//            }
//        })

        BlockaLogger.v("FlutterService", "Legacy remove TODO")
    }
}
