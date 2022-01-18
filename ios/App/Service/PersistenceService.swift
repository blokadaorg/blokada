//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Combine

protocol PersistenceService {
    func getString(forKey: String) -> AnyPublisher<String, Error>
    func setString(_ value: String, forKey: String) -> AnyPublisher<Ignored, Error>
    func delete(forKey: String) -> AnyPublisher<Ignored, Error>
    func getBool(forKey: String) -> AnyPublisher<Bool, Error>
    func setBool(_ value: Bool, forKey: String) -> AnyPublisher<Ignored, Error>
}

class LocalStoragePersistenceService: PersistenceService {

    private let localStorage = UserDefaults.standard

    func getString(forKey: String) -> AnyPublisher<String, Error> {
        return Just(true)
        .tryMap { _ in
            guard let it = self.localStorage.string(forKey: forKey) else {
                throw CommonError.emptyResult
            }
            return it
        }
        .eraseToAnyPublisher()
    }
    
    func setString(_ value: String, forKey: String) -> AnyPublisher<Ignored, Error> {
        return Just(value)
        .tryMap { value in self.localStorage.set(value, forKey: forKey) }
        .map { _ in true }
        .eraseToAnyPublisher()
    }

    func delete(forKey: String) -> AnyPublisher<Ignored, Error> {
        return Just(true)
        .tryMap { value in self.localStorage.removeObject(forKey: forKey) }
        .map { _ in true }
        .eraseToAnyPublisher()
    }

    func getBool(forKey: String) -> AnyPublisher<Bool, Error> {
        return Just(true)
        .tryMap { _ in self.localStorage.bool(forKey: forKey) }
        .eraseToAnyPublisher()
    }

    func setBool(_ value: Bool, forKey: String) -> AnyPublisher<Ignored, Error> {
        return Just(value)
        .tryMap { value in self.localStorage.set(value, forKey: forKey) }
        .map { _ in true }
        .eraseToAnyPublisher()
    }

}

class ICloudPersistenceService: PersistenceService {

    private let iCloud = NSUbiquitousKeyValueStore()

    func getString(forKey: String) -> AnyPublisher<String, Error> {
        return Just(true)
        .tryMap { _ in
            guard let it = self.iCloud.string(forKey: forKey) else {
                throw CommonError.emptyResult
            }
            return it
        }
        .eraseToAnyPublisher()
    }

    func setString(_ value: String, forKey: String) -> AnyPublisher<Ignored, Error> {
        return Just(value)
        .tryMap { value in
            self.iCloud.set(value, forKey: forKey)
            self.iCloud.synchronize()
        }
        .map { _ in true }
        .eraseToAnyPublisher()
    }

    func delete(forKey: String) -> AnyPublisher<Ignored, Error> {
        return Just(true)
        .tryMap { value in
            self.iCloud.removeObject(forKey: forKey)
            self.iCloud.synchronize()
        }
        .map { _ in true }
        .eraseToAnyPublisher()
    }

    func getBool(forKey: String) -> AnyPublisher<Bool, Error> {
        return Just(true)
        .tryMap { _ in self.iCloud.bool(forKey: forKey) }
        .eraseToAnyPublisher()
    }

    func setBool(_ value: Bool, forKey: String) -> AnyPublisher<Ignored, Error> {
        return Just(value)
        .tryMap { value in
            self.iCloud.set(value, forKey: forKey)
            self.iCloud.synchronize()
        }
        .map { _ in true }
        .eraseToAnyPublisher()
    }

}

class KeychainPersistenceService: PersistenceService {

    private let keychain = KeychainSwift()

    init() {
        keychain.synchronizable = true
    }

    func getString(forKey: String) -> AnyPublisher<String, Error> {
        return Just(true)
        .tryMap { _ in
            guard let it = self.keychain.get(forKey) else {
                throw CommonError.emptyResult
            }
            return it
        }
        .eraseToAnyPublisher()
    }

    func setString(_ value: String, forKey: String) -> AnyPublisher<Ignored, Error> {
        return Fail(error: "KeychainPersistenceService is a legacy persistence, do not save to it")
            .eraseToAnyPublisher()
    }

    func delete(forKey: String) -> AnyPublisher<Ignored, Error> {
        return Fail(error: "KeychainPersistenceService is a legacy persistence, do not delete from it")
            .eraseToAnyPublisher()
    }

    func getBool(forKey: String) -> AnyPublisher<Bool, Error> {
        return Fail(error: "KeychainPersistenceService is a legacy persistence, does not read booleans")
            .eraseToAnyPublisher()
    }

    func setBool(_ value: Bool, forKey: String) -> AnyPublisher<Ignored, Error> {
        return Fail(error: "KeychainPersistenceService is a legacy persistence, does not save booleans")
            .eraseToAnyPublisher()
    }

}

class PersistenceServiceMock: PersistenceService {

    var mockGetString: (String) -> AnyPublisher<String, Error> = { forKey in
        return Fail<String, Error>(error: CommonError.emptyResult)
            .eraseToAnyPublisher()
    }

    func getString(forKey: String) -> AnyPublisher<String, Error> {
        return mockGetString(forKey)
    }
    
    func setString(_ value: String, forKey: String) -> AnyPublisher<Ignored, Error> {
        return Deferred { () -> AnyPublisher<Ignored, Error> in
            return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func delete(forKey: String) -> AnyPublisher<Ignored, Error> {
        return Deferred { () -> AnyPublisher<Ignored, Error> in
            return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func getBool(forKey: String) -> AnyPublisher<Bool, Error> {
        return Fail<Bool, Error>(error: CommonError.emptyResult)
            .eraseToAnyPublisher()
    }

    func setBool(_ value: Bool, forKey: String) -> AnyPublisher<Ignored, Error> {
        return Deferred { () -> AnyPublisher<Ignored, Error> in
            return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

}
