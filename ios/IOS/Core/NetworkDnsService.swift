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
import NetworkExtension
import UIKit

class NetworkDnsService {

    static let shared = NetworkDnsService()
    
    private let log = Logger("NetDns")

    private init() {}

    func isBlokadaNetworkDnsEnabled(done: @escaping Callback<Bool>) {
        self.getManager { error, manager in
            guard error == nil else {
                return onMain { done(error, nil) }
            }
            
            onMain { done(nil, manager?.isEnabled ?? false) }
        }
    }

    func saveBlokadaNetworkDns(tag: String, name: String, done: @escaping Callback<Void>) {
        self.getManager { error, manager in
            guard error == nil else {
                return onMain { done(error, nil) }
            }

            let dohSettings = NEDNSOverHTTPSSettings(servers: [ "34.117.212.222" ])
            dohSettings.serverURL = URL(string: "https://cloud.blokada.org/\(tag)/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")")
            manager?.dnsSettings = dohSettings
            manager?.saveToPreferences { error in
                guard error == nil else {
                    // An ugly way to check for this error..
                    if (error?.localizedDescription == "configuration is unchanged") {
                        return onMain { done(nil, nil) }
                    }

                    self.log.e("saveBlokadaNetworkDns: saveToPreferences failed".cause(error))
                    return onMain { done(error, nil) }
                }

                onMain { done(nil, nil) }
            }
        }
    }

    func openSettingsScreen() {
        let alert = UIAlertController(title: "Open", message: "To give permissions tap on 'Change Settings' button", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Change Settings", style: .default, handler: { action in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }))

        SharedActionsService.shared.presentAlert(alert)
    }

    private func getManager(done: @escaping Callback<NEDNSSettingsManager>) {
        NEDNSSettingsManager.shared().loadFromPreferences { (error) in onBackground {
            guard error == nil else {
                self.log.e("getManager: loadFromPreferences failed".cause(error))
                return done(error, nil)
            }
            
            return done(nil, NEDNSSettingsManager.shared())
        }}
    }
}
