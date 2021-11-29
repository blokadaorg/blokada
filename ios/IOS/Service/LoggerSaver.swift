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

    static var logFile: URL? {
        let fileManager = FileManager.default
        return fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.blocka.app")?.appendingPathComponent("blokada.log")
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
        print(line)

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

    static func loadLog(limit: Int) -> [String] {
        guard let logFile = logFile else {
            return []
        }

        var logs = [String]()
        if let fileHandle = try? FileHandle(forReadingFrom: logFile) {
            let streamer = StreamReader(fileHandle: fileHandle)
            streamer?.last(limit * 64) // Approximate 64 chars per line
            while let line = streamer?.nextLine() {
                logs.append(line)
            }
            streamer?.close()
        }
        return logs
    }

    static func cleanup() {
        onBackground {
            guard let logFile = logFile else { return }

            try? self.loadLog(limit: 10000)
                .joined(separator: "\n")
                .write(to: logFile, atomically: true, encoding: .utf8)
        }
    }
}
