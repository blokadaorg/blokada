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

import SwiftUI
import Flutter
import Factory

struct FlutterHomeView: UIViewControllerRepresentable {

    @Injected(\.flutter) private var flutter

    func makeUIViewController(context: Context) -> FlutterViewController {
        let engine = self.flutter.getEngine()
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        self.flutter.setupChannels(controller: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: FlutterViewController, context: Context) {
    }

}
