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

    // Captive-portal hosts that must resolve via the network's own DNS. Portal
    // login pages often exist only there (e.g. wifi.finnair.com is NXDOMAIN
    // publicly), so DoH can never answer them and the user can't log in.
    // Entries match whole-label suffixes. Keep them portal-only: never a whole
    // airline or corporate domain.
    private static let captivePortalDomains = [
        // Apple's own probe hosts. iOS already exempts its captive detection;
        // kept as a cheap hedge for networks where no sign-in sheet appears.
        "captive.apple.com",
        "www.appleiphonecell.com", "www.itools.info", "www.ibook.info",
        "www.airport.us", "www.thinkdifferent.us",
        // In-flight
        "wifi.finnair.com", "nordic-sky.finnair.com", "inflightinternet.com",
        "wifionboard.com", "gogoinflight.com", "alaskawifi.com", "deltawifi.com",
        "aainflight.com", "unitedwifi.com", "wifi.united.com", "southwestwifi.com",
        "flyfi.com", "lufthansa-flynet.com", "wingsconnect.aero", "shop.ba.com",
        "starlink.ba.com", "freewifi.airfrance.com", "wifi.airfrance.com",
        "connect.flysas.com", "norwegianwifi.com",
        // Rail
        "wifionice.de", "wifi.bahn.de", "iceportal.de", "wifi.sncf", "ombord.sj.se",
        "ombord.info", "onboard.eurostar.com", "portalefrecce.it", "railnet.oebb.at",
        "cdwifi.cz",
        // Hotel and café portal platforms
        "network-auth.com", "purpleportal.net", "securelogin.arubanetworks.com",
        "securelogin.hpe.com", "odyssys.net",
    ]

    // Portal domains bypass the profile; the trailing Connect rule keeps DoH
    // applied to everything else instead of relying on an unstated default.
    private static func captivePortalRules() -> [NEOnDemandRule] {
        let evaluate = NEOnDemandRuleEvaluateConnection()
        evaluate.connectionRules = [
            NEEvaluateConnectionRule(matchDomains: captivePortalDomains, andAction: .neverConnect)
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
            it.onDemandRules = PrivateDnsService.captivePortalRules()
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
