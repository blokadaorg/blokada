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
import os.log

// This class is mostly a copy of Logger from the app.
// Network Extension doesn't share code with the app.

class NELogger {
    static func e(_ message: String) {
        let line = makeLine(LogPrio.ERR.rawValue, "NETX", message)
        os_log("%{public}s", log: .default, type: .error, line)
        LoggerSaver.log(line)
    }

    static func w(_ message: String) {
        let line = makeLine(LogPrio.WARN.rawValue, "NETX", message)
        os_log("%{public}s", log: .default, type: .error, line)
        LoggerSaver.log(line)
    }

    static func v(_ message: String) {
        let line = makeLine(LogPrio.VERBOSE.rawValue, "NETX", message)
        os_log("%{public}s", log: .default, type: .error, line) // .debug did not print
        LoggerSaver.log(line)
    }

    private static func makeLine(_ priority: Int, _ component: String, _ message: String) -> String {
        return "\(priorityToLetter(priority: priority)) \(component.padding(toLength: 10, withPad: " ", startingAt: 0)) \(message)"
    }

    private static func priorityToLetter(priority: Int) -> String {
        switch priority {
        case LogPrio.ERR.rawValue:
            return "E"
        case LogPrio.WARN.rawValue:
            return "W"
        default:
            return " "
        }
    }
}

enum LogPrio: Int {
    case ERR = 6
    case WARN = 5
    case VERBOSE = 2
}

class LoggerSaver {
    // Must match the app's LoggerSaver/CoreBinding subdirectory. Logs stay in
    // the shared group but under the standard Library hierarchy because
    // devicectl on Xcode 26.5+ can only list/copy files inside Library/, not
    // the container root or custom top-level directories.
    static let logSubdirectory = "Library/Application Support/Blokada"

    static var logFile: URL? {
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.blocka.app") else {
            return nil
        }

        let logsDir = container.appendingPathComponent(logSubdirectory, isDirectory: true)
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let target = logsDir.appendingPathComponent("blokada.log")
        let legacy = container.appendingPathComponent("blokada.log")
        if fileManager.fileExists(atPath: legacy.path),
           !fileManager.fileExists(atPath: target.path) {
            try? fileManager.moveItem(at: legacy, to: target)
        }

        return target
    }

    private static var formatter: DateFormatter {
       let formatter = DateFormatter()
       formatter.dateFormat = "HH:mm:ss.SSS"
       formatter.timeZone = TimeZone.init(secondsFromGMT: 0)
       return formatter
    }

    static func log(_ message: String) {
        guard let logFile = logFile else {
            return
        }

        let timestamp = formatter.string(from: Date())

        let line = (timestamp + " " + message)

        guard let data = (line + "\n").data(using: String.Encoding.utf8) else { return }

        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logFile, options: .atomicWrite)
        }
    }
}
