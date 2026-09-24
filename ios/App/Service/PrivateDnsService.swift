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

enum PrivateDnsProfileStateKind {
    case enabled
    case disabled
    case unavailable
}

struct PrivateDnsProfileState {
    let kind: PrivateDnsProfileStateKind
    let serverUrl: String?
}

// Allows to check and save our Private DNS profile to be later selected by the user.
// The UX for user is far from ideal, but the is no other way currently in iOS.
protocol PrivateDnsServiceIn {
    func isPrivateDnsProfileActive() -> AnyPublisher<Bool, Error>
    func savePrivateDnsProfile(tag: String, name: String?) -> AnyPublisher<Ignored, Error>
    func getPrivateDnsServerUrl() -> AnyPublisher<String, Error>
    func getPrivateDnsState() -> AnyPublisher<PrivateDnsProfileState, Error>
}

class PrivateDnsServiceMock: PrivateDnsServiceIn {

    // Sim runs without a real DNS profile, so report "already configured" so
    // the app skips the install wizard and proceeds straight into the active
    // path — matches what the real PrivateDnsService would report on a real
    // device that's already onboarded.
    private var active = true

    func isPrivateDnsProfileActive() -> AnyPublisher<Bool, Error> {
        return Just(active).setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func savePrivateDnsProfile(tag: String, name: String?) -> AnyPublisher<Ignored, Error> {
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func getPrivateDnsServerUrl() -> AnyPublisher<String, Error> {
        return Just("https://cloud.blokada.org/mock").setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    func getPrivateDnsState() -> AnyPublisher<PrivateDnsProfileState, Error> {
        return Just(
            PrivateDnsProfileState(
                kind: active ? .enabled : .disabled,
                serverUrl: "https://cloud.blokada.org/mock"
            )
        )
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

}

class PrivateDnsService: PrivateDnsServiceIn {

    private lazy var manager = NEDNSSettingsManager.shared()

    // OS captive-portal probe hosts. These must resolve via system DNS, or iOS
    // can't detect a walled-garden network and never shows its sign-in sheet.
    // Keep this to Apple's own probe hosts; portal login domains are out of scope.
    private static let captiveProbeDomains = [
        "captive.apple.com",
        "www.appleiphonecell.com", "www.itools.info", "www.ibook.info",
        "www.airport.us", "www.thinkdifferent.us",
    ]

    // Probe domains bypass the profile; the trailing Connect rule keeps DoH
    // applied to everything else instead of relying on an unstated default.
    private static func captiveProbeRules() -> [NEOnDemandRule] {
        let evaluate = NEOnDemandRuleEvaluateConnection()
        evaluate.connectionRules = [
            NEEvaluateConnectionRule(matchDomains: captiveProbeDomains, andAction: .neverConnect)
        ]
        return [evaluate, NEOnDemandRuleConnect()]
    }

    func isPrivateDnsProfileActive() -> AnyPublisher<Bool, Error> {
        print("getting manager")
        return getManager()
        .tryMap { it in
            print("mapping manager result")
            // TODO: possibly check the exact serverURL here
            return it.isEnabled
        }
        .catch { err in
            Just(false).setFailureType(to: Error.self)
        }
        .eraseToAnyPublisher()
    }
    
    func getPrivateDnsServerUrl() -> AnyPublisher<String, Error> {
        return getManager()
            .tryMap { it in
                // Check if the DNS over HTTPS settings are present
                guard let dnsSettings = it.dnsSettings as? NEDNSOverHTTPSSettings else {
                    throw "dns setting not found"
                }
                // Ensure there is at least one server URL and return it
                guard let serverURL = dnsSettings.serverURL?.absoluteString else {
                    return ""
                }
                return serverURL
            }
            .eraseToAnyPublisher()
    }

    func getPrivateDnsState() -> AnyPublisher<PrivateDnsProfileState, Error> {
        return getManager()
            .map { it in
                guard let dnsSettings = it.dnsSettings as? NEDNSOverHTTPSSettings else {
                    return PrivateDnsProfileState(kind: .unavailable, serverUrl: nil)
                }

                let serverUrl = dnsSettings.serverURL?.absoluteString
                return PrivateDnsProfileState(
                    kind: it.isEnabled ? .enabled : .disabled,
                    serverUrl: serverUrl
                )
            }
            .eraseToAnyPublisher()
    }

    func savePrivateDnsProfile(tag: String, name: String?) -> AnyPublisher<Ignored, Error> {
        return getManager()
        // Configure the new profile
        .tryMap { it -> NEDNSSettingsManager in
            let profile = NEDNSOverHTTPSSettings(servers: [])
            if let name = name {
                // Older tag + name
                let nameSanitized = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
                profile.serverURL = URL(string: "https://cloud.blokada.org/\(tag)/\(nameSanitized)")
            } else {
                // Only tag used (v3 api)
                profile.serverURL = URL(string: "https://cloud.blokada.org/\(tag)")
            }
            BlockaLogger.v("PrivateDns", "URL set to: \(profile.serverURL)")
            it.dnsSettings = profile
            it.onDemandRules = PrivateDnsService.captiveProbeRules()
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
