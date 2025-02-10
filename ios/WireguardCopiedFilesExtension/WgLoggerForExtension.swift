// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation
import os.log

public class Logger {
    static var global: Logger?

    func log(message: String) {
        NELogger.v(message)
    }

    static func configureGlobal(tagged tag: String, withFilePath filePath: String?) {
        if Logger.global != nil {
            return
        }
        Logger.global = Logger()
        var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
        if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion += " (\(appBuild))"
        }

        Logger.global?.log(message: "App version: \(appVersion)")
    }
}

func wg_log(_ type: OSLogType, staticMessage msg: StaticString) {
    os_log(msg, log: OSLog.default, type: type)
    Logger.global?.log(message: "\(msg)")
}

func wg_log(_ type: OSLogType, message msg: String) {
    os_log("%{public}s", log: OSLog.default, type: type, msg)
    Logger.global?.log(message: msg)
}
