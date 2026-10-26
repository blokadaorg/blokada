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

// Persistence: secure values go to the Keychain, even when also asked to be
// backed up. Secure and backed up values (the account) use a Keychain item
// that syncs through iCloud Keychain, so the account still comes back on a
// reinstall or a new device without a plain copy in iCloud key-value storage.
// Secure values that are not backed up (the keypair) stay on this device.

class CoreBinding: CoreOps {

    let shareLog = CurrentValueSubject<URL?, Never>(nil)

    @Injected(\.flutter) private var flutter

    // Logger
    private var fileName: String
    private let maxFileSize: UInt64
    private var fileURL: URL?
    private var currentSize: UInt64 = 0
    private let queue = DispatchQueue(label: "com.app.logfilemanager.queue", qos: .background)

    // Persistence
    private let localStorage = UserDefaults.standard
    private let sharedStorage = UserDefaults(suiteName: "group.net.blocka.app")
    private let iCloud = NSUbiquitousKeyValueStore()
    private let keychain = KeychainSwift()
    private let backupKeychain = KeychainSwift()

    init() {
        maxFileSize = 5 * 1024 * 1024
        fileName = ""
        fileURL = getFilename(fileName)
        CoreOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    
        // Keypair needs to stay local
        keychain.synchronizable = false
        backupKeychain.synchronizable = true
    }

    // Logger

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

            return completion(.success(()))
        }
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
                return completion(.success(()))
            } catch {
                print("Error writing log: \(error)")
                return completion(.failure("Error writing log: \(error)"))
            }
        }
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

    // The support chat uploads only the end of the log, which its server caps.
    // Runs on the write queue, so batches already queued are in the tail. A
    // cut file starts after the first newline, so it opens with a whole line
    // and never inside a multi-byte character.
    func doReadLogTail(maxBytes: Int64, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            guard let url = self.fileURL, FileManager.default.fileExists(atPath: url.path) else {
                return completion(.success(""))
            }
            do {
                let fileHandle = try FileHandle(forReadingFrom: url)
                defer {
                    try? fileHandle.close()
                }
                let length = try fileHandle.seekToEnd()
                let start = length > UInt64(maxBytes) ? length - UInt64(maxBytes) : 0
                try fileHandle.seek(toOffset: start)
                var data = try fileHandle.readToEnd() ?? Data()
                if start > 0, let newline = data.firstIndex(of: 0x0A) {
                    data = data.suffix(from: data.index(after: newline))
                }
                return completion(.success(String(decoding: data, as: UTF8.self)))
            } catch {
                print("Error reading log: \(error)")
                return completion(.failure("Error reading log: \(error)"))
            }
        }
    }

    func doShareFile(completion: @escaping (Result<Void, Error>) -> Void) {
        shareLog.send(fileURL)
        return completion(.success(()))
    }

    func getFilename(_ file: String) -> URL? {
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.blocka.app"
        ) else {
            return nil
        }

        // Keep logs in the shared group (the network extension writes here too)
        // but under the standard Library hierarchy: devicectl on Xcode 26.5+ can
        // only list/copy files inside Library/, not files at the container root
        // or in custom top-level dirs, so those are unreachable for host-side
        // log fetching.
        let logsDir = container.appendingPathComponent(LoggerSaver.logSubdirectory, isDirectory: true)
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)

        guard !file.isEmpty else {
            return logsDir
        }

        let target = logsDir.appendingPathComponent(file)

        // Preserve the existing append-only log previously written to the root.
        let legacy = container.appendingPathComponent(file)
        if fileManager.fileExists(atPath: legacy.path),
           !fileManager.fileExists(atPath: target.path) {
            try? fileManager.moveItem(at: legacy, to: target)
        }

        return target
    }

    // Persistence
    
    func doSave(key: String, value: String, isSecure: Bool, isBackup: Bool,
                completion: @escaping (Result<Void, Error>) -> Void) {
        if (key == "blockaweb:status") {
            saveAppStatusForBlockaweb(value)
            completion(.success(()))
        } else if (isSecure) {
            guard secureStore(isBackup).set(value, forKey: key, withAccess: .accessibleAfterFirstUnlock) else {
                return completion(.failure("failed saving \(key) to keychain"))
            }
            if (isBackup) {
                removeFromICloud(key)
            }
            completion(.success(()))
        } else if (isBackup) {
            self.iCloud.set(value, forKey: key)
            self.iCloud.synchronize()
            completion(.success(()))
        } else {
            self.localStorage.set(value, forKey: key)
            completion(.success(()))
        }
    }

    func doLoad(key: String, isSecure: Bool, isBackup: Bool,
                completion: @escaping (Result<String, Error>) -> Void) {
        if (key == "blockaweb:ping") {
            guard let it = loadPingFromBlockaweb() else {
                return completion(.failure(CommonError.emptyResult))
            }
            completion(.success(it))
        } else if (isSecure) {
            if let it = secureStore(isBackup).get(key) {
                return completion(.success(it))
            }
            guard isBackup, let it = migrateFromICloud(key) else {
                return completion(.failure(CommonError.emptyResult))
            }
            completion(.success(it))
        } else if (isBackup) {
            guard let it = self.iCloud.string(forKey: key) else {
                return completion(.failure(CommonError.emptyResult))
            }
            completion(.success(it))
        } else {
            guard let it = self.localStorage.string(forKey: key) else {
                return completion(.failure(CommonError.emptyResult))
            }
            completion(.success(it))
        }
    }

    func doDelete(key: String, isSecure: Bool, isBackup: Bool,
                  completion: @escaping (Result<Void, Error>) -> Void) {
        if (isSecure) {
            secureStore(isBackup).delete(key)
            if (isBackup) {
                removeFromICloud(key)
            }
            completion(.success(()))
        } else if (isBackup) {
            self.iCloud.removeObject(forKey: key)
            completion(.success(()))
        } else {
            self.localStorage.removeObject(forKey: key)
            completion(.success(()))
        }
    }

    private func secureStore(_ isBackup: Bool) -> KeychainSwift {
        return isBackup ? backupKeychain : keychain
    }

    // Older versions kept secure and backed up values (the account) in iCloud
    // key-value storage, unencrypted. Move such a value into the Keychain on
    // first read, and drop the iCloud copy only once the Keychain holds it, so
    // a failed write never loses the account.
    private func migrateFromICloud(_ key: String) -> String? {
        guard let it = self.iCloud.string(forKey: key) else {
            return nil
        }
        if backupKeychain.set(it, forKey: key, withAccess: .accessibleAfterFirstUnlock) {
            removeFromICloud(key)
        }
        return it
    }

    private func removeFromICloud(_ key: String) {
        guard self.iCloud.object(forKey: key) != nil else { return }
        self.iCloud.removeObject(forKey: key)
        self.iCloud.synchronize()
    }

    // Special case to provide app status to blockaweb extension
    func saveAppStatusForBlockaweb(_ value: String) {
        // We save to a file accessible by both the app, and the extension (using app groups)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.net.blocka.app") {
            let fileURL = containerURL.appendingPathComponent("blockaweb.app.status.json")
            try? value.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    func loadPingFromBlockaweb() -> String? {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.net.blocka.app") {
            let fileURL = containerURL.appendingPathComponent("blockaweb.ping.json")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    return content
                } catch {
                    return nil
                }
            }
        }
        return nil
    }
}

extension Container {
    var core: Factory<CoreBinding> {
        self { CoreBinding() }.singleton
    }
}
