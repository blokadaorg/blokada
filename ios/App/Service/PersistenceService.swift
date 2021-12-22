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
    func setString(_ value: String, forKey: String) -> AnyPublisher<Void, Error>
    func delete(forKey: String) -> AnyPublisher<Void, Error>
}

class LocalStoragePersistenceService: PersistenceService {

    private let localStorage = UserDefaults.standard

    func getString(forKey: String) -> AnyPublisher<String, Error> {
        return Deferred { () -> AnyPublisher<String, Error> in
            guard let it = self.localStorage.string(forKey: forKey) else {
                return Fail<String, Error>(error: CommonError.emptyResult)
                    .eraseToAnyPublisher()
            }

            return Just(it).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    func setString(_ value: String, forKey: String) -> AnyPublisher<Void, Error> {
        return Deferred { () -> AnyPublisher<Void, Error> in
            self.localStorage.set(value, forKey: forKey)

            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func delete(forKey: String) -> AnyPublisher<Void, Error> {
        return Deferred { () -> AnyPublisher<Void, Error> in
            self.localStorage.removeObject(forKey: forKey)

            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

}

class ICloudPersistenceService: PersistenceService {

    private let iCloud = NSUbiquitousKeyValueStore()

    func getString(forKey: String) -> AnyPublisher<String, Error> {
        return Deferred { () -> AnyPublisher<String, Error> in
            guard let it = self.iCloud.string(forKey: forKey) else {
                return Fail<String, Error>(error: CommonError.emptyResult)
                    .eraseToAnyPublisher()
            }

            return Just(it).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func setString(_ value: String, forKey: String) -> AnyPublisher<Void, Error> {
        return Deferred { () -> AnyPublisher<Void, Error> in
            self.iCloud.set(value, forKey: forKey)
            self.iCloud.synchronize()

            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func delete(forKey: String) -> AnyPublisher<Void, Error> {
        return Deferred { () -> AnyPublisher<Void, Error> in
            self.iCloud.removeObject(forKey: forKey)
            self.iCloud.synchronize()

            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

}

class KeychainPersistenceService: PersistenceService {

    private let keychain = KeychainSwift()

    init() {
        keychain.synchronizable = true
    }

    func getString(forKey: String) -> AnyPublisher<String, Error> {
        return Deferred { () -> AnyPublisher<String, Error> in
            guard let it = self.keychain.get(forKey) else {
                return Fail<String, Error>(error: CommonError.emptyResult)
                    .eraseToAnyPublisher()
            }

            return Just(it).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func setString(_ value: String, forKey: String) -> AnyPublisher<Void, Error> {
        return Fail(error: "KeychainPersistenceService is a legacy persistence, do not save to it")
            .eraseToAnyPublisher()
    }

    func delete(forKey: String) -> AnyPublisher<Void, Error> {
        return Fail(error: "KeychainPersistenceService is a legacy persistence, do not delete from it")
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
    
    func setString(_ value: String, forKey: String) -> AnyPublisher<Void, Error> {
        return Deferred { () -> AnyPublisher<Void, Error> in
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func delete(forKey: String) -> AnyPublisher<Void, Error> {
        return Deferred { () -> AnyPublisher<Void, Error> in
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

}
