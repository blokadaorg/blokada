//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import NetworkExtension

// Allows to check and save our Private DNS profile to be later selected by the user.
// The UX for user is far from ideal, but the is no other way currently in iOS.
protocol PrivateDnsServiceIn {
    func isPrivateDnsProfileActive() -> AnyPublisher<Bool, Never>
    func savePrivateDnsProfile(tag: String, name: String?) -> AnyPublisher<Ignored, Error>
}

class PrivateDnsServiceMock: PrivateDnsServiceIn {

    private var active = false

    func isPrivateDnsProfileActive() -> AnyPublisher<Bool, Never> {
        let a = active
        active = true
        return Just(a).eraseToAnyPublisher()
    }

    func savePrivateDnsProfile(tag: String, name: String?) -> AnyPublisher<Ignored, Error> {
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

}

class PrivateDnsService: PrivateDnsServiceIn {

    private lazy var manager = NEDNSSettingsManager.shared()

    func isPrivateDnsProfileActive() -> AnyPublisher<Bool, Never> {
        print("getting manager")
        return getManager()
        .tryMap { it in
            print("mapping manager result")
            // TODO: possibly check the exact serverURL here
            return it.isEnabled
        }
        .catch { err in
            Just(false)
        }
        .eraseToAnyPublisher()
    }

    func savePrivateDnsProfile(tag: String, name: String?) -> AnyPublisher<Ignored, Error> {
        return getManager()
        // Configure the new profile
        .tryMap { it -> NEDNSSettingsManager in
            guard let name = name else {
                // Only tag used (v3 api)
                let profile = NEDNSOverHTTPSSettings(servers: [ "34.117.212.222" ])
                profile.serverURL = URL(string: "https://cloud.blokada.org/\(tag)")
                BlockaLogger.v("PrivateDns", "URL set to: \(profile.serverURL)")
                it.dnsSettings = profile
                return it
            }

            // Older tag + name
            let nameSanitized = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            let profile = NEDNSOverHTTPSSettings(servers: [ "34.117.212.222" ])
            profile.serverURL = URL(string: "https://cloud.blokada.org/\(tag)/\(nameSanitized)")
            BlockaLogger.v("PrivateDns", "URL set to: \(profile.serverURL)")
            it.dnsSettings = profile
            return it
        }
        // Save it to the OS preferences
        .flatMap { it in
            Future<Ignored, Error> { promise in
                it.saveToPreferences { error in
                    guard error == nil else {
                        // XXX: An ugly way to check for this error..
                        if (error!.localizedDescription == "configuration is unchanged") {
                            return promise(.success(true))
                        }

                        // XXX: Even uglier error I don't understand that seems safe to ignore
                        if let err = error as NSError?, err.domain == "NEDNSSettingsErrorDomain" {
                            BlockaLogger.w("PrivateDns", "Ignoring the 'configuration is stale' error")
                            return promise(.success(true))
                        }

                        return promise(.failure(error!))
                    }

                    return promise(.success(true))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // Ensures we load from preferences before using manager. A pattern that seemed important to other managers.
    // XXX: This might be an overkill.
    private func getManager() -> AnyPublisher<NEDNSSettingsManager, Error> {
        return Future<NEDNSSettingsManager, Error> { promise in
            self.manager.loadFromPreferences { error in
                guard error == nil else {
                    return promise(.failure(error!))
                }
                
                return promise(.success(self.manager))
            }
        }
        .eraseToAnyPublisher()
    }

}
