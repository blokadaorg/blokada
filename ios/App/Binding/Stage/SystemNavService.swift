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
import UIKit

class SystemNavService {

    func openSystemSettings() {
        UIApplication.shared.open(URL(string: "App-Prefs:root=General")!)
    }

    func openAppSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }

    func openInBrowser(_ link: URLComponents) {
        if let url = link.url {
            UIApplication.shared.open(url, options: [:])
        } else {
            BlockaLogger.e("SystemNav", "Could not open link: \(link)")
        }
    }

}
