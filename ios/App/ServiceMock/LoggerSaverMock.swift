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

class LoggerSaver {

    private static var logs = [String]()

    static var logFile: URL? {
        nil
    }

    static func log(_ message: String) {
        onMain {
            self.logs.append(message)
            print(message)
        }
    }

    static func loadLog(limit: Int) -> [String] {
        return self.logs
    }

    static func cleanup() {
    }
}
