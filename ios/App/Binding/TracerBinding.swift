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

struct TracerBinding: TracerOps {
    let shareLog = CurrentValueSubject<URL?, Never>(nil)

    @Injected(\.env) private var env
    @Injected(\.flutter) private var flutter
    
    init() {
        TracerOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doStartFile(filename: String, template: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let logFile = getFilename(filename) else {
            return completion(.failure("failed opening file"))
        }

        guard let data = (template).data(using: String.Encoding.utf8) else {
            return completion(.failure("failed encoding template"))
        }

        try? data.write(to: logFile, options: .atomicWrite)
        completion(.success(()))
    }

    func doSaveBatch(filename: String, batch: String, mark: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let logFile = getFilename(filename) else {
            return completion(.failure("failed opening file"))
        }

        guard let data = (batch).data(using: String.Encoding.utf8) else {
            return completion(.failure("failed encoding batch"))
        }

        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = try? FileHandle(forUpdating: logFile) {
                defer { fileHandle.closeFile() }
                do {
                    guard var pos = try findLastOccurrence(of: mark, fileHandle) else {
                        return completion(.failure("not found placement mark: \(mark)"))
                    }
                    fileHandle.seek(toFileOffset: pos)
                    let dataAfterPos = fileHandle.readDataToEndOfFile()
                    fileHandle.seek(toFileOffset: pos)
                    let textData = batch.data(using: .utf8)!
                    fileHandle.write(textData)
                    fileHandle.write(dataAfterPos)
                } catch {
                    return completion(.failure("seeking placement mark in file failed"))
                }
            }
        } else {
            return completion(.failure("no existing log file to write batch to"))
        }
        return completion(.success(()))
    }

    func doShareFile(filename: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let logFile = getFilename(filename) else {
            return completion(.failure("failed opening file"))
        }

        shareLog.send(logFile)
        return completion(.success(()))
    }

    func doFileExists(filename: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let logFile = getFilename(filename) else {
            return completion(.failure("failed opening file"))
        }

        let exists = FileManager.default.fileExists(atPath: logFile.path)
        return completion(.success(exists))
    }
    
    func doDeleteFile(filename: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let logFile = getFilename(filename) else {
            return completion(.failure("failed opening file"))
        }

        do {
            try FileManager.default.removeItem(at: logFile)
            return completion(.success(()))
        } catch {
            return completion(.failure(error))
        }
    }

    func findLastOccurrence(of searchString: String, _ fileHandle: FileHandle) throws -> UInt64? {
        assert(searchString.count == 3, "Search string must have exactly 3 characters.")

        let searchData = searchString.data(using: .utf8)!
        let chunkSize: UInt64 = 4096
        var buffer = Data(capacity: Int(chunkSize))
        
        var offset: UInt64 = fileHandle.seekToEndOfFile()
        
        while offset > 0 {
            // Ensure we don't miss the string straddling two chunks.
            let chunkOffset = max(3, offset) - 3
            fileHandle.seek(toFileOffset: chunkOffset)

            let chunk = fileHandle.readData(ofLength: Int(min(chunkSize, offset)))
            buffer = chunk + buffer

            if let range = buffer.range(of: searchData, options: .backwards) {
                return chunkOffset + UInt64(range.lowerBound)
            }

            // Keep last 3 bytes for next iteration.
            buffer = buffer.dropFirst(min(chunk.count, buffer.count - 3))
            offset = chunkOffset
        }
        
        return nil
    }

    func getFilename(_ file: String) -> URL? {
        let fileManager = FileManager.default
        return fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.blocka.app"
        )?.appendingPathComponent(file)
    }
}

extension Container {
    var tracer: Factory<TracerBinding> {
        self { TracerBinding() }.singleton
    }
}
