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
import Factory
import Combine

extension URL: Identifiable {
    public var id: Int {
        hashValue
    }
}

class LoggerBinding: LoggerOps {

    let shareLog = CurrentValueSubject<URL?, Never>(nil)

    @Injected(\.env) private var env
    @Injected(\.flutter) private var flutter

    private var fileName: String
    private let maxFileSize: UInt64
    private var fileURL: URL?
    private var currentSize: UInt64 = 0
    private let queue = DispatchQueue(label: "com.app.logfilemanager.queue", qos: .background)
    
    init() {
        maxFileSize = 5 * 1024 * 1024
        fileName = ""
        fileURL = getFilename(fileName)
        LoggerOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doUseFilename(filename: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let file = getFilename(filename) else {
            return completion(.failure("failed opening file"))
        }

        self.fileName = filename
        fileURL = file
        
        queue.sync {
            if !FileManager.default.fileExists(atPath: file.path) {
                FileManager.default.createFile(atPath: file.path, contents: nil, attributes: nil)
                currentSize = 0
            } else {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    if let size = attributes[.size] as? UInt64 {
                        currentSize = size
                    }
                } catch {
                    print("Error initializing log: \(error)")
                    return completion(.failure("Error initializing log: \(error)"))
                }
            }
        }

        completion(.success(()))
    }

    func doSaveBatch(batch: String, completion: @escaping (Result<Void, Error>) -> Void) {
        
        queue.async {
            guard let data = (batch).data(using: .utf8) else { return }
            do {
                let fileHandle = try FileHandle(forWritingTo: self.fileURL!)
                defer {
                    try? fileHandle.close()
                }
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: data)
                self.currentSize += UInt64(data.count)
                self.trimLogFileIfNeeded()
            } catch {
                print("Error writing log: \(error)")
                return completion(.failure("Error writing log: \(error)"))
            }
        }

        return completion(.success(()))
    }
    
    func trimLogFileIfNeeded() {
        guard currentSize > maxFileSize else { return }

        do {
            let targetSize = UInt64(Double(maxFileSize) * 0.8)
            let bytesToRemove = currentSize - targetSize

            let fileHandle = try FileHandle(forReadingFrom: fileURL!)
            defer {
                try? fileHandle.close()
            }

            var trimOffset: UInt64 = 0
            var bytesRead: UInt64 = 0
            let bufferSize = 4096 // 4 KB
            let buffer = Data(capacity: bufferSize)

            let newlineData = "\n".data(using: .utf8)!

            fileHandle.seek(toFileOffset: 0)
            while bytesRead < bytesToRemove {
                let data = fileHandle.readData(ofLength: bufferSize)
                if data.isEmpty { break } // End of file

                if let range = data.range(of: newlineData) {
                    // Found a newline character
                    trimOffset = bytesRead + UInt64(range.upperBound)
                }
                bytesRead += UInt64(data.count)
            }

            if trimOffset > 0 {
                // Read remaining data after trimOffset
                fileHandle.seek(toFileOffset: trimOffset)
                let remainingData = fileHandle.readDataToEndOfFile()

                // Overwrite the file with the remaining data
                try remainingData.write(to: fileURL!, options: .atomic)

                currentSize = UInt64(remainingData.count)
            }
        } catch {
            print("Error trimming log file: \(error)")
        }
    }

    func doShareFile(completion: @escaping (Result<Void, Error>) -> Void) {
        shareLog.send(fileURL)
        return completion(.success(()))
    }

    func getFilename(_ file: String) -> URL? {
        let fileManager = FileManager.default
        return fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.blocka.app"
        )?.appendingPathComponent(file)
    }
}

extension Container {
    var logger: Factory<LoggerBinding> {
        self { LoggerBinding() }.singleton
    }
}
