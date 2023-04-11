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
import Factory
import UIKit

class EnvBinding: EnvOps {
    @Injected(\.flutter) private var flutter

    init() {
        EnvOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func isProduction() -> Bool {
        return production
    }
    
    func isRunningTests() -> Bool {
        return runningTests
    }
    
    func getUserAgent() -> String {
        return "blokada/\(appVersion) (ios-\(osVersion) six \(buildType) \(cpu) apple \(deviceModel) touch api compatible)"
    }

    func getAppVersion() -> String {
        return appVersion
    }

    func getDeviceName() -> String {
        return deviceName
    }
    
    func getAliasForLease() -> String {
        return aliasForLease
    }

    func getDeviceTag() -> String {
        return deviceTag
    }

    func setDeviceTag(tag: String) {
        deviceTag = tag
    }

    func doGetEnvPayload(completion: @escaping (Result<EnvPayload, Error>) -> Void) {
        completion(Result.success(EnvPayload(
            appVersion: appVersion,
            osVersion: osVersion,
            buildFlavor: "six",
            buildType: buildType,
            cpu: cpu,
            deviceBrand: "apple",
            deviceModel: deviceModel,
            deviceName: deviceName
        )))
    }

    func doGetUserAgent(completion: @escaping (Result<String, Error>) -> Void) {
        completion(Result.success(getUserAgent()))
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

extension Container {
    var env: Factory<EnvBinding> {
        self { EnvBinding() }.singleton
    }
}
