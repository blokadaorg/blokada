//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import UIKit

// This class is a copy from the App module that generates the same user agent.
// Check EnvBinding. There was no point to add a dependency to the NETX.
class Env {
    func getUserAgent() -> String {
        // Family support here was not neccessary as we have no VPN for family.
        // but if one day...
        return "blokada/\(appVersion) (ios-\(osVersion) \(flavor) \(buildType) \(cpu) apple \(deviceModel) touch api compatible)"
    }
    
    fileprivate var flavor: String {
        #if FAMILY
            return "family"
        #else
            return "six"
        #endif
    }

    fileprivate var cpu: String {
        #if PREVIEW
            return "sim"
        #else
            return "apple"
        #endif
    }

    fileprivate var buildType: String {
        #if DEBUG
            return "debug"
        #else
            return "release"
        #endif
    }

    fileprivate let deviceModel = UIDevice.current.modelName

    fileprivate let deviceName = UIDevice.current.name

    fileprivate var deviceTag = ""

    fileprivate let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "6.0.0-debug"

    fileprivate let osVersion = UIDevice.current.systemVersion

    private let aliasForLease = UIDevice.current.name

    private let runningTests = UserDefaults.standard.bool(forKey: "isRunningTests")

    private var production: Bool {
        return buildType == "release" && !runningTests
    }
}

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
