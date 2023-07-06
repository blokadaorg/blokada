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
import Factory
import NetworkExtension

typealias CloudDnsProfileActivated = Bool
typealias CloudDeviceTag = String
typealias CloudBlocklists = [String]
typealias CloudActivityRetention = String

class DeviceBinding: DeviceOps {

    // Lastest device tag info from backend. Used for Cloud DNS profile and Plus VPN
    var deviceTagHot: AnyPublisher<CloudDeviceTag, Never> {
        self.writeDeviceTag.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    // Latest user blocklists choice (only backend IDs, needs to be translated client side)
    var blocklistsHot: AnyPublisher<CloudBlocklists, Never> {
        self.writeBlocklists.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }
    
    // User selected activity retention (may be empty for "no retention")
    var activityRetentionHot: AnyPublisher<CloudActivityRetention, Never> {
        self.writeRetention.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    // Whether user has currently paused adblocking or not
    var adblockingPausedHot: AnyPublisher<Bool, Never> {
        self.writePaused.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    @Injected(\.flutter) private var flutter
    @Injected(\.env) private var env
    @Injected(\.account) private var account
    @Injected(\.stage) private var stage
    @Injected(\.commands) private var commands

    private lazy var enteredForegroundHot = stage.enteredForegroundHot
    private lazy var activeTabHot = stage.activeTab
    private lazy var accountIdHot = account.accountIdHot

    fileprivate let writeCloudEnabled = CurrentValueSubject<Bool?, Never>(nil)
    fileprivate let writeDeviceTag = CurrentValueSubject<CloudDeviceTag?, Never>(nil)
    fileprivate let writeBlocklists = CurrentValueSubject<CloudBlocklists?, Never>(nil)
    fileprivate let writeRetention = CurrentValueSubject<String?, Never>(nil)
    fileprivate let writePaused = CurrentValueSubject<Bool?, Never>(nil)

    private let bgQueue = DispatchQueue(label: "CloudRepoBgQueue")
    private var cancellables = Set<AnyCancellable>()

    private lazy var manager = NEDNSSettingsManager.shared()

    init() {
        onDeviceTagChangeUpdateEnv()
        DeviceOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func setActivityRetention(_ retention: CloudActivityRetention) -> AnyPublisher<Ignored, Error> {
        commands.execute(.setRetention, retention)
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    func setPaused(_ paused: Bool) -> AnyPublisher<Ignored, Error> {
        if (paused) {
            commands.execute(.disableCloud)
        } else {
            commands.execute(.enableCloud)
        }
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    func setBlocklists(_ lists: CloudBlocklists) -> AnyPublisher<Ignored, Error> {
        return Fail(error: "not imple").eraseToAnyPublisher();
    }

    func doCloudEnabled(enabled: Bool,
                        completion: @escaping (Result<Void, Error>) -> Void) {
        writePaused.send(!enabled)
        completion(Result.success(()))
    }

    func doRetentionChanged(retention: String, completion: @escaping (Result<Void, Error>) -> Void) {
        writeRetention.send(retention)
        completion(Result.success(()))
    }

    func doDeviceTagChanged(deviceTag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        writeDeviceTag.send(deviceTag)
        completion(.success(()))
    }

    private func onDeviceTagChangeUpdateEnv() {
        deviceTagHot
        .sink(onValue: { it in
            self.env.setDeviceTag(tag: it)
        })
        .store(in: &cancellables)
    }

}

extension Container {
    var cloud: Factory<DeviceBinding> {
        self { DeviceBinding() }.singleton
    }
}
