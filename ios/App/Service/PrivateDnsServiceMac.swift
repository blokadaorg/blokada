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
    
    // Fetch DNS profile from API
    func fetchDNSProfile(completion: @escaping (Data?) -> Void) {
        guard let tag = pendingProfileTag else {
            BlockaLogger.e("PrivateDnsMac", "No pending profile tag")
            completion(nil)
            return
        }
        
        // Build API URL with encoded parameters
        var urlComponents = URLComponents(string: "https://api.cloud.blokada.org/apple")
        urlComponents?.queryItems = [
            URLQueryItem(name: "device_tag", value: tag),
            URLQueryItem(name: "device_name", value: pendingProfileName ?? "")
        ]
        
        guard let url = urlComponents?.url else {
            BlockaLogger.e("PrivateDnsMac", "Failed to build API URL")
            completion(nil)
            return
        }
        
        BlockaLogger.v("PrivateDnsMac", "Fetching profile from: \(url.absoluteString)")
        
        // Create URL request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        // Perform the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                BlockaLogger.e("PrivateDnsMac", "Error fetching profile: \(error)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                BlockaLogger.e("PrivateDnsMac", "Invalid response")
                completion(nil)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                BlockaLogger.e("PrivateDnsMac", "API returned status: \(httpResponse.statusCode)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                BlockaLogger.e("PrivateDnsMac", "No data received")
                completion(nil)
                return
            }
            
            BlockaLogger.v("PrivateDnsMac", "Successfully fetched profile (\(data.count) bytes)")
            completion(data)
        }.resume()
    }
    
    func promptToInstallDNSProfile() {
        // Fetch profile from API
        fetchDNSProfile { [weak self] profileData in
            guard let profileData = profileData else {
                BlockaLogger.e("PrivateDnsMac", "Failed to fetch profile")
                return
            }
            
            // Switch to main thread for file operations and UI
            DispatchQueue.main.async {
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
