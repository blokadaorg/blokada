//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
