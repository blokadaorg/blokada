//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import UIKit
import SwiftUI

class LogViewModel: ObservableObject {

    @Published var logs = [String]()
    @Published var monitoring = false
    private var timer: Timer?

    func loadLog() {
        self.logs = LoggerSaver.loadLog(limit: 500)
    }

    func toggleMonitorLog() {
        BlockaLogger.v("Debug", "Toggle log monitoring")
        onMain {
            self.loadLog()

            if self.timer == nil {
                self.startMonitoringLog()
            } else {
                self.stopMonitoringLog()
            }
        }
    }

    func startMonitoringLog() {
        self.monitoring = true
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
            self.loadLog()
        }
    }

    func stopMonitoringLog() {
        self.monitoring = false
        self.timer?.invalidate()
        self.timer = nil
    }

    func colorForLine(_ line: String) -> Color {
        if line.contains(" E ") {
            return Color.cError
        } else if line.contains(" W ") {
            return Color.cActivePlus
        } else {
            return Color.primary
        }
    }

    func share() {
        onBackground {
            sleep(1)
            onMain {
                guard let file = LoggerSaver.logFile else {
                    return BlockaLogger.e("Logger", "Could not share log file: no log file")
                }

                Services.dialog.shareFile(file)
            }
        }
    }
}
