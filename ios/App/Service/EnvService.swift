//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import UIKit

class EnvService {

    var cpu: String {
        #if PREVIEW
            return "sim"
        #else
            return "apple"
        #endif
    }

    var buildType: String {
        #if DEBUG
            return "debug"
        #else
            return "release"
        #endif
    }

    var isProduction: Bool {
        return buildType == "release" && !isRunningTests
    }

    let deviceModel = UIDevice.current.modelName

    let deviceName = UIDevice.current.name

    var deviceTag = ""

    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "6.0.0-debug"

    let osVersion = UIDevice.current.systemVersion

    let aliasForLease = UIDevice.current.name

    func userAgent() -> String {
        return "blokada/\(appVersion) (ios-\(osVersion) six \(buildType) \(cpu) apple \(deviceModel) touch api compatible)"
    }

    let baseUrl = "https://api.blocka.net"

    let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests")
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
