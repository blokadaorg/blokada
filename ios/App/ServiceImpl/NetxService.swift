//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import NetworkExtension

class NetxService: NetxServiceIn {

    private var netxStateHot: AnyPublisher<NetworkStatus, Never> {
        writeNetxState.compactMap { $0 }.eraseToAnyPublisher()
    }

    private var permsHot: AnyPublisher<Granted, Never> {
        writePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    fileprivate let writeNetxState = CurrentValueSubject<NetworkStatus?, Never>(nil)
    fileprivate let writePerms = CurrentValueSubject<Granted?, Never>(nil)

    fileprivate let queryNetxStateT = SimpleTasker<Ignored>("queryNetxState")

    private var netxStateObserver = Atomic<NSObjectProtocol?>(nil)
    private var cancellables = Set<AnyCancellable>()
    private let bgQueue = DispatchQueue(label: "NetxServiceBgQueue")
    private var manager = Atomic<NETunnelProviderManager?>(nil)

    func start() {
        onQueryNetxState()
        onPermsGranted_startMonitoringNetx()
    }

    func setConfig(_ config: NetxConfig) -> AnyPublisher<Ignored, Error> {
        return getManager()
        .tryMap { manager -> NETunnelProviderManager in
            let dns = self.getUserDnsIp(config.deviceTag)
            BlockaLogger.v("NetxService", "setConfig: gateway: \(config.gateway.niceName()), tag: \(config.deviceTag), dns: \(dns)")

            let protoConfig = NETunnelProviderProtocol()
            protoConfig.providerBundleIdentifier = "net.blocka.app.engine"
            protoConfig.serverAddress = config.gateway.niceName()
            protoConfig.username = ""

            protoConfig.providerConfiguration = [
                "version": "6",
                "userAgent": config.userAgent,
                "privateKey": config.privateKey,
                "gatewayId": config.gateway.public_key,
                "ipv4": config.gateway.ipv4,
                "ipv6": config.gateway.ipv6,
                "port": String(config.gateway.port),
                "vip4": config.lease.vip4,
                "vip6": config.lease.vip6,
                "dns": dns
            ]

            manager.protocolConfiguration = protoConfig
            manager.localizedDescription = "BLOKADA"
            //manager.isEnabled = true
            return manager
        }
        .flatMap { manager -> AnyPublisher<Ignored, Error> in
            return Future<Ignored, Error> { promise in
                manager.saveToPreferences() { error -> Void in
                    if let error = error {
                        return promise(.failure("setConfig: could not save".cause(error)))
                    }

                    return promise(.success(true))
                }
            }
            .eraseToAnyPublisher()
        }
        .flatMap { _ in self.netxStateHot.first() }
        .flatMap { netxState -> AnyPublisher<Ignored, Error> in
            if (netxState.active) {
                BlockaLogger.v("NetxService", "Updating NETX config live")
                return self.switchConfigLive(config)
            } else {
                return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }

    private func switchConfigLive(_ config: NetxConfig) -> AnyPublisher<Ignored, Error> {
        let connect = [
            NetworkCommand.connect.rawValue,
            config.privateKey,
            config.gateway.public_key,
            config.gateway.ipv4,
            config.gateway.ipv6,
            String(config.gateway.port),
            config.lease.vip4,
            config.lease.vip6,
            self.getUserDnsIp(config.deviceTag)
        ].joined(separator: " ")

        return self.sendNetxMessage(msg: connect)
        .map { _ in true }
        .eraseToAnyPublisher()
        // TODO: emit network status here?
    }

    func startVpn() -> AnyPublisher<Ignored, Error> {
        return startVpnInternal()
        .tryCatch { error in
            // A delayed retry (total 3 attemps that wait up to 5 sec)
            return self.startVpnInternal()
            .retry(1)
        }
        .eraseToAnyPublisher()
    }

    private func startVpnInternal() -> AnyPublisher<Ignored, Error> {
        return netxStateHot.filter { !$0.inProgress }.first()
        .flatMap { state -> AnyPublisher<Ignored, Error> in
            // VPN already started, ignore
            if state.active {
                return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            return self.getManager()
            // Change config
            .tryMap { manager -> NETunnelProviderManager in
                manager.isEnabled = true
                manager.isOnDemandEnabled = true
                return manager
            }
            // Save config
            .flatMap { manager in
                return Future<NETunnelProviderManager, Error> { promise in
                    manager.saveToPreferences() { error -> Void in
                        if let error = error {
                            return promise(.failure("startVpn".cause(error)))
                        }

                        return promise(.success(manager))
                    }
                }
                .eraseToAnyPublisher()
            }
            // Actually start VPN
            .tryMap { manager -> Ignored in
                let connection = manager.connection as! NETunnelProviderSession
                do {
                    BlockaLogger.v("NetxService", "Starting tunnel")
                    try connection.startVPNTunnel()
                    return true
                } catch {
                    throw error
                }
            }
            .delay(for: 0.5, scheduler: self.bgQueue)
            .map { _ in self.queryNetxState() }
            .map { _ in true }
            // Wait for completion or timeout
            .flatMap { _ in
                Publishers.Merge(
                    // Wait until active state is reported
                    self.netxStateHot.filter { $0.active }.first().tryMap { _ in true }
                    .eraseToAnyPublisher(),

                    // Also make a timeout
                    Just(true)
                    .delay(for: 3.0, scheduler: self.bgQueue)
                    .flatMap { _ in self.netxStateHot.first() }
                    .tryMap { state -> Ignored in
                        if !state.active {
                            throw "timeout"
                        }
                        return true
                    }
                    .eraseToAnyPublisher()
                )
                .first()
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func stopVpn() -> AnyPublisher<Ignored, Error> {
        return netxStateHot.filter { !$0.inProgress }.first()
        .flatMap { state -> AnyPublisher<Ignored, Error> in
            // VPN already stopped, ignore
            if !state.active {
                return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            return self.getManager()
            // Change config
            .tryMap { manager -> NETunnelProviderManager in
                //manager.isEnabled = true
                manager.isOnDemandEnabled = false
                return manager
            }
            // Save config
            .flatMap { manager in
                return Future<NETunnelProviderManager, Error> { promise in
                    manager.saveToPreferences() { error -> Void in
                        if let error = error {
                            return promise(.failure("stopVpn".cause(error)))
                        }

                        return promise(.success(manager))
                    }
                }
                .eraseToAnyPublisher()
            }
            // Actually stop VPN
            .tryMap { manager -> Ignored in
                let connection = manager.connection as! NETunnelProviderSession
                BlockaLogger.v("NetxService", "Stopping tunnel")
                connection.stopVPNTunnel()
                return true
            }
            // Wait for completion or timeout
            .flatMap { _ in
                Publishers.Merge(
                    // Wait until inactive state is reported
                    self.netxStateHot.filter { !$0.active }.first().tryMap { _ in true }
                    .eraseToAnyPublisher(),

                    // Also make a timeout
                    Just(true)
                    .delay(for: 15.0, scheduler: self.bgQueue)
                    .flatMap { _ in self.netxStateHot.first() }
                    .tryMap { state -> Ignored in
                        if state.active {
                            throw "stopvpn timeout"
                        }
                        return true
                    }
                    .eraseToAnyPublisher()
                )
                .first()
                .eraseToAnyPublisher()
            }
            // As a last resort re-check current state
            // It seems NETX can timeout at weird situations but it actually stops
            .map { _ in self.queryNetxState() }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func createVpnProfile() -> AnyPublisher<Ignored, Error> {
        // According to Apple docs we need to call loadFromPreferences at least once
        BlockaLogger.v("NetxService", "Creating new VPN profile")
        return Just(NETunnelProviderManager())
        .map { manager -> NETunnelProviderManager in
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            return manager
        }
        .flatMap { manager in
            return Future<NETunnelProviderManager, Error> { promise in
                manager.loadFromPreferences { error -> Void in
                    if let error = error {
                        return promise(.failure(error))
                    }

                    return promise(.success(manager))
                }
            }
        }
        .flatMap { manager in self.setInitialConfig(manager) }
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    // Make a request outside of the tunnel while tunnel is established.
    // It is used while VPN is on, in order to be able to do requests even
    // if tunnel is cut out (for example because it expired).
    func makeProtectedRequest(url: String, method: String, body: String) -> AnyPublisher<String, Error> {
        let request = [
            NetworkCommand.request.rawValue, url, method, ":body:", body
        ].joined(separator: " ")
        return sendNetxMessage(msg: request)
    }

    // Will create a NETX timer that is not killed in bg. No param means unpause.
    func changePause(until: Date? = nil) -> AnyPublisher<Ignored, Error> {
        return Just(until ?? Date())
        .tryMap { until in Int(until.timeIntervalSince(Date())) }
        .map { seconds in
            [ NetworkCommand.pause.rawValue, String(seconds) ]
            .joined(separator: " ")
        }
        .flatMap { request in self.sendNetxMessage(msg: request) }
        .map { _ in self.queryNetxState() }
        .map { _ in true }
        .eraseToAnyPublisher()
    }

    func getStatePublisher() -> AnyPublisher<NetworkStatus, Never> {
        return netxStateHot
    }
    
    func getPermsPublisher() -> AnyPublisher<Granted, Never> {
        return permsHot
    }

    func checkPerms() {
        // Getting the state will emit perms state to self.writePerms
        queryNetxState()
    }

    // Creates initial configuration (when user grants VPN permissions).
    // Must be overwritten with setConfig() before calling startVpn().
    private func setInitialConfig(_ manager: NETunnelProviderManager) -> AnyPublisher<Ignored, Error> {
        return Just(manager)
        .tryMap { manager -> NETunnelProviderManager in
            let protoConfig = NETunnelProviderProtocol()
            protoConfig.providerBundleIdentifier = "net.blocka.app.engine"
            protoConfig.serverAddress = "127.0.0.1"
            protoConfig.username = ""
            protoConfig.providerConfiguration = [:]
            manager.protocolConfiguration = protoConfig
            manager.localizedDescription = "BLOKADA"
            manager.isEnabled = true
            return manager
        }
        .flatMap { manager -> AnyPublisher<Ignored, Error> in
            return Future<Ignored, Error> { promise in
                manager.saveToPreferences() { error -> Void in
                    if let error = error {
                        return promise(.failure("setInitialConfig".cause(error)))
                    }

                    return promise(.success(true))
                }
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    private func onPermsGranted_startMonitoringNetx() {
        permsHot
        .sink(onValue: { granted in
            if granted {
                // Calling startMonitoringNetx several times is ok
                self.startMonitoringNetx()
            } else {
                // Emit disconnected (fresh app install, or perms rejected)
                self.writeNetxState.send(NetworkStatus.disconnected())
            }
            
        })
        .store(in: &cancellables)
    }

    private func startMonitoringNetx() {
        BlockaLogger.v("NetxService", "startMonitoringNetx")

        if let observer = netxStateObserver.value {
            NotificationCenter.default.removeObserver(observer)
        }

        getManager()
        .tryMap { manager -> NETunnelProviderSession in
            guard let connection = manager.connection as? NETunnelProviderSession else {
                throw "startMonitoringNetx: no connection in manager"
            }
            return connection
        }
        .sink(
            onValue: { connection in
                self.netxStateObserver.value = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name.NEVPNStatusDidChange,
                    object: connection,
                    queue: OperationQueue.main,
                    using: self.netxStateListener
                )

                // Check the current state as we'll only get state changes
                self.queryNetxState()
            },
            onFailure: { err in
                BlockaLogger.e("NetxService", "Could not start montioring".cause(err))
            }
        )
        .store(in: &cancellables)
    }

    private lazy var netxStateListener: (Notification) -> Void = { notification in
        let connection = notification.object as! NETunnelProviderSession
        switch (connection.status) {
        case NEVPNStatus.connected:
            self.queryNetxState()
        case NEVPNStatus.connecting:
            BlockaLogger.v("NetxService", "Connecting")
            self.writeNetxState.send(NetworkStatus.inProgress())
        case NEVPNStatus.disconnecting:
            BlockaLogger.v("NetxService", "Disconnecting")
            self.writeNetxState.send(NetworkStatus.inProgress())
        case NEVPNStatus.reasserting:
            BlockaLogger.v("NetxService", "Reasserting")
            self.writeNetxState.send(NetworkStatus.inProgress())
        case NEVPNStatus.disconnected:
            BlockaLogger.v("NetxService", "Disconnected")
            self.writeNetxState.send(NetworkStatus.disconnected())
        case NEVPNStatus.invalid:
            BlockaLogger.v("NetxService", "Invalid")
            self.writeNetxState.send(NetworkStatus.disconnected())
        default:
            BlockaLogger.v("NetxService", "Unknown")
            self.writeNetxState.send(NetworkStatus.disconnected())
        }
    }

    private func onQueryNetxState() {
        queryNetxStateT.setTask { _ in
            self.getManager()
            // Get the status information from the manager connection
            .tryMap { manager -> NetworkStatus in
                guard let connection = manager.connection as? NETunnelProviderSession else {
                    throw "queryNetxState: no connection in manager"
                }

                var gatewayId: String? = nil
                if let server = (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration?["gatewayId"] {
                    gatewayId = server as? String
                }

                let active = connection.status == NEVPNStatus.connected && manager.isEnabled
                let inProgress = [
                    NEVPNStatus.connecting, NEVPNStatus.disconnecting, NEVPNStatus.reasserting
                ].contains(connection.status)

                return NetworkStatus(
                    active: active, inProgress: inProgress,
                    gatewayId: gatewayId, pauseSeconds: 0
                )
            }
            // Get the pause information from the NETX itself (ignore error)
            .flatMap { status  -> AnyPublisher<(NetworkStatus, String), Error> in
                BlockaLogger.v("NetxService", "Query state: before report")
                return Publishers.CombineLatest(
                    Just(status).setFailureType(to: Error.self).eraseToAnyPublisher(),
                    self.sendNetxMessage(msg: NetworkCommand.report.rawValue)
                    // First retry, maybe we queried too soon
                    .tryCatch { err in
                        self.sendNetxMessage(msg: NetworkCommand.report.rawValue)
                        .delay(for: 3.0, scheduler: self.bgQueue)
                        .retry(1)
                    }
                    // Then ignore error, it's not the crucial part of the query
                    //.tryCatch { err in Just("0") }
                )
                .eraseToAnyPublisher()
            }
            // Put it all together
            .tryMap { it -> NetworkStatus in
                BlockaLogger.v("NetxService", "Query state: after report")
                let (status, response) = it
                var pauseSeconds = 0
                if response != "off" {
                    pauseSeconds = Int(response) ?? 0
                }
                return NetworkStatus(
                    active: status.active, inProgress: status.inProgress,
                    gatewayId: status.gatewayId, pauseSeconds: pauseSeconds
                )
            }
            .tryMap { it in self.writeNetxState.send(it) }
            .tryMap { _ in true }
            .tryCatch { err -> AnyPublisher<Ignored, Error> in
                BlockaLogger.e(
                    "NetxService",
                    "queryNetxState: could not get status info".cause(err)
                )

                // Re-load the manager (maybe VPN profile removed)
                self.manager = Atomic(nil)

                if let e = err as? CommonError, e == .vpnNoPermissions {
                    BlockaLogger.w("NetxService", "marking VPN as disabled")
                    self.writeNetxState.send(NetworkStatus.disconnected())
                }

                throw err
            }
            .eraseToAnyPublisher()
        }
    }

    private func queryNetxState() {
        queryNetxStateT.send()
    }

    private func sendNetxMessage(msg: String) -> AnyPublisher<String, Error> {
        // Wait until NETX is initialized before any requests
        writeNetxState.first()
        .flatMap { _ in self.getManager() }
        // Prepare connection to send message through
        .tryMap { manager -> (Data, NETunnelProviderSession) in
            let data = msg.data(using: String.Encoding.utf8)!
            let connection = manager.connection as! NETunnelProviderSession
            return (data, connection)
        }
        // Send the message and wait for response or error or timeout
        .flatMap { it -> AnyPublisher<String, Error> in
            let (data, connection) = it
            return Publishers.Merge(
                // Actual request to NETX
                Future<String, Error> { promise in
                    do {
                        try connection.sendProviderMessage(data) { reply in
                            guard let reply = reply else {
                                return promise(.failure("sendNetxMessage: got a nil reply back for command".cause(msg)))
                            }

                            let data = String.init(data: reply, encoding: String.Encoding.utf8)!
                            if (data.starts(with: "error: code: ")) {
                                let code = Int(data.components(separatedBy: "error: code: ")[1])!
                                return promise(.failure(NetworkError.http(code)))
                            } else if (data.starts(with: "error: ")) {
                                return promise(.failure(data))
                            } else {
                                return promise(.success(data))
                            }
                        }
                    } catch {
                        return promise(.failure("sendNetxMessage: sending message failed".cause(error)))
                    }
                }
                .eraseToAnyPublisher(),

                // Also make a timeout
                Just(true)
                .delay(for: 5.0, scheduler: self.bgQueue)
                .tryMap { state -> String in
                    throw "NETX message timeout"
                }
                .eraseToAnyPublisher()
            )
            .first() // Whatever comes first: a response, or the timeout throwing
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    // Returns a manager ref, or loads it from API if not available
    private func getManager() -> AnyPublisher<NETunnelProviderManager, Error> {
        if let m = manager.value {
            return Just(m).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return loadManager()
        .map { m in
            self.manager = Atomic(m)
            return m
        }
        .eraseToAnyPublisher()
    }

    private func loadManager() -> AnyPublisher<NETunnelProviderManager, Error> {
        // Get the manager object or timeout
        return Publishers.Merge(
            // Actual query for object
            Future<NETunnelProviderManager, Error> { promise in
                BlockaLogger.w("NetxService", "getManager: asking")
                return NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
                    BlockaLogger.w("NetxService", "getManager: got callback")
                    if let error = error {
                        return promise(
                            .failure("getManager: loadAllPreferences".cause(error))
                        )
                    }

                    // Remove multiple profiles, we just need one
                    let managersCount = managers?.count ?? 0
                    if (managersCount > 1) {
                        BlockaLogger.w("NetxService", "getManager: Found multiple VPN profiles, deleting others")
                        for i in 0..<(managersCount - 1) {
                            managers![i].removeFromPreferences(completionHandler: nil)
                        }
                    }
                    BlockaLogger.w("NetxService", "getManager: after managersCount")

                    // No profiles means no perms, otherwise normal flow
                    if (managersCount == 0) {
                        self.writePerms.send(false)
                        return promise(.failure(CommonError.vpnNoPermissions))
                    } else {
                        self.writePerms.send(true)
                        // According to Apple docs we need to call loadFromPreferences at least once
                        let manager = managers![0]
                        BlockaLogger.w("NetxService", "getManager: before second load")
                        manager.loadFromPreferences { error in
                            BlockaLogger.w("NetxService", "getManager: second load callback rec")
                            if let error = error {
                                return promise(
                                    .failure("getManager: loadFromPreferences".cause(error))
                                )
                            }

                            return promise(.success(manager))
                        }
                    }
                }
            }
            .eraseToAnyPublisher(),

            // Also make a timeout
            Just(true)
            .delay(for: 2.0, scheduler: self.bgQueue)
            .tryMap { state -> NETunnelProviderManager in
                throw "getManager timeout"
            }
            .eraseToAnyPublisher()
        )
        .first() // Whatever comes first: a manager object, or the timeout throwing
        .eraseToAnyPublisher()
    }

    private func getUserDnsIp(_ tag: String) -> String {
        if tag.count == 6 {
            // 6 chars old tag
            return "2001:678:e34:1d::\(tag.prefix(2)):\(tag.suffix(4))"
        } else {
            // 11 chars new tag
            return "2001:678:e34:1d::\(tag.prefix(3)):\(tag.dropFirst(3).prefix(4)):\(tag.suffix(4))"
        }
    }

    func refreshOnForeground() {}
}
