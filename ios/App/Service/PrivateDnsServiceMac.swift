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

import UIKit
import Foundation
import Combine
import NetworkExtension

// macOS implementation that generates configuration profiles instead of directly saving
class PrivateDnsServiceMac: PrivateDnsServiceIn {
    
    private lazy var manager = NEDNSSettingsManager.shared()
    
    // Store the profile data for later generation
    private var pendingProfileTag: String?
    private var pendingProfileName: String?
    
    func isPrivateDnsProfileActive() -> AnyPublisher<Bool, Error> {
        // On MacOs, this api was always returning false, so we just hardcode it
        // The actual check (that is working) is in getPrivateDnsServerUrl
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func savePrivateDnsProfile(tag: String, name: String?) -> AnyPublisher<Ignored, Error> {
        // On macOS, we don't save directly. Instead, store the data for profile generation
        self.pendingProfileTag = tag
        self.pendingProfileName = name
        
        BlockaLogger.v("PrivateDnsMac", "Stored profile data - tag: \(tag), name: \(name ?? "nil")")
        
        // Return success immediately since actual profile will be generated on demand
        return Just(true)
            .setFailureType(to: Error.self)
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
    
    // Generate DNS profile with stored tag and name
    func generateDNSProfile() -> Data? {
        guard let tag = pendingProfileTag else {
            BlockaLogger.e("PrivateDnsMac", "No pending profile tag")
            return nil
        }
        
        // Generate the server URL based on tag and name
        let serverURL: String
        if let name = pendingProfileName {
            let nameSanitized = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            serverURL = "https://cloud.blokada.org/\(tag)/\(nameSanitized)"
        } else {
            serverURL = "https://cloud.blokada.org/\(tag)"
        }
        
        BlockaLogger.v("PrivateDnsMac", "Generating profile with URL: \(serverURL)")
        
        let profileDict: [String: Any] = [
            "PayloadContent": [[
                "DNSSettings": [
                    "DNSProtocol": "HTTPS",
                    "ServerURL": serverURL,
                    // Optional: Add server addresses if you have specific IPs
                    // "ServerAddresses": ["your.server.ip"],
                ],
                "OnDemandRules": [[
                    "Action": "Connect"
                ]],
                "PayloadType": "com.apple.dnsSettings.managed",
                "PayloadIdentifier": "com.blokada.dns.\(tag)",
                "PayloadUUID": UUID().uuidString,
                "PayloadVersion": 1,
                "PayloadDisplayName": "Blokada DNS - \(pendingProfileName ?? tag)"
            ]],
            "PayloadDisplayName": "Blokada Private DNS",
            "PayloadDescription": "This profile configures your device to use Blokada's encrypted DNS servers.",
            "PayloadIdentifier": "com.blokada.dns-profile",
            "PayloadOrganization": "Blocka AB",
            "PayloadRemovalDisallowed": false,
            "PayloadType": "Configuration",
            "PayloadUUID": UUID().uuidString,
            "PayloadVersion": 1,
            "PayloadScope": "User"
        ]
        
        return try? PropertyListSerialization.data(
            fromPropertyList: profileDict,
            format: .xml,
            options: 0
        )
    }
    
    func promptToInstallDNSProfile() {
        guard let profileData = generateDNSProfile() else {
            BlockaLogger.e("PrivateDnsMac", "Failed to generate profile")
            return
        }
        
        // Create a temporary file
        let tempDirectory = FileManager.default.temporaryDirectory
        let profileURL = tempDirectory.appendingPathComponent("Blokada-DNS.mobileconfig")
        
        do {
            // Write profile to temporary file
            try profileData.write(to: profileURL)
            
            // Open the file - this will prompt the user to install it
            UIApplication.shared.open(profileURL) { success in
                if success {
                    BlockaLogger.v("PrivateDnsMac", "Profile opened successfully")
                } else {
                    BlockaLogger.e("PrivateDnsMac", "Failed to open profile")
                }
                
                // Clean up temp file after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    try? FileManager.default.removeItem(at: profileURL)
                }
            }
        } catch {
            BlockaLogger.e("PrivateDnsMac", "Error saving profile: \(error)")
        }
    }
    
    // Ensures we load from preferences before using manager
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
