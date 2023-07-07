//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Combine
import NetworkExtension

class WgService: NetxServiceIn {

    var wgStateHot: AnyPublisher<VpnStatus, Never> {
        writeWgState.compactMap { $0 }.eraseToAnyPublisher()
    }

    private var permsHot: AnyPublisher<Granted, Never> {
        writePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    fileprivate let writeWgState = CurrentValueSubject<VpnStatus?, Never>(nil)
    fileprivate let writePerms = CurrentValueSubject<Granted?, Never>(nil)

    fileprivate let checkPermsT = SimpleTasker<Ignored>("checkPerms")

    private let bgQueue = DispatchQueue(label: "WgServiceBgQueue")
    private var cancellables = Set<AnyCancellable>()

    var tunnelsManager = Atomic<TunnelsManager?>(nil)
    var tunnelsTracker: TunnelsTracker?

    let localIps = [
        "::/0", "1.0.0.0/8", "2.0.0.0/8", "3.0.0.0/8", "4.0.0.0/6", "8.0.0.0/7", "11.0.0.0/8",
        "12.0.0.0/6", "16.0.0.0/4", "32.0.0.0/3", "64.0.0.0/2", "128.0.0.0/3", "160.0.0.0/5",
        "168.0.0.0/6", "172.0.0.0/12", "172.32.0.0/11", "172.64.0.0/10", "172.128.0.0/9",
        "173.0.0.0/8", "174.0.0.0/7", "176.0.0.0/4", "192.0.0.0/9", "192.128.0.0/11",
        "192.160.0.0/13", "192.169.0.0/16", "192.170.0.0/15", "192.172.0.0/14", "192.176.0.0/12",
        "192.192.0.0/10", "193.0.0.0/8", "194.0.0.0/7", "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4",
    ]

    func start() {
        initTunnelsManager()
        onPermsGranted_startMonitoringWg()
        onCheckPerms()

        // First state will be soon rewritten by actual state unless something is wrong
        //self.writeWgState.send(VpnStatus.inProgress())
    }
    
    private func initTunnelsManager() {
        TunnelsManager.create { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                BlockaLogger.e("WgService", "Failed to init TunnelsManager".cause(error))
                ErrorPresenter.showErrorAlert(error: error, from: nil)
            case .success(let tunnelsManager):
                let tunnelsTracker = TunnelsTracker(tunnelsManager: tunnelsManager)

                tunnelsTracker.onTunnelState = { status in
                    BlockaLogger.v("WgService", "TunnelsManager status updated")
                    self.writeWgState.send(status)
                }

                self.tunnelsManager = Atomic(tunnelsManager)
                self.tunnelsTracker = tunnelsTracker

                //self.workaroundFirstConfigProblem(manager: tunnelsManager)
                BlockaLogger.v("WgService", "TunnelsManager is initialized")
                tunnelsTracker.triggerCurrentStatus()
                self.checkPerms()
            }
        }
    }
    // This is a hacky workaround to fix a problem when for some reason first config
    // delivered to wg-ios leads to leaking (IP is not hidden). On subsequent config
    // changes everything works fine. This call is used to provide a temporary first
    // config, which causes wg-ios to reload on the second (actual) config.
    private func workaroundFirstConfigProblem(manager: TunnelsManager) {
        // Dont apply when no prems yet
        if manager.numberOfTunnels() == 0 {
            return
        }

        let key = PrivateKey()
        var interface = InterfaceConfiguration(privateKey: key)
        var peer = PeerConfiguration(publicKey: key.publicKey)
        let tunnelConfiguration = TunnelConfiguration(name: "Blokada+ (...)", interface: interface, peers: [peer])
        let container = manager.tunnel(at: 0)

        manager.modify(tunnel: container, tunnelConfiguration: tunnelConfiguration, onDemandOption: .off) { error -> Void in
            guard error == nil else {
                return BlockaLogger.e("WgService", "Could not do workaround".cause(error))
            }

            BlockaLogger.e("WgService", "Applied workaround config")
        }
    }

    func setConfig(_ config: VpnConfig) -> AnyPublisher<Ignored, Error> {
        return getManager()
        // Skip if anything is missing
        .tryMap { manager in
            if manager.numberOfTunnels() == 0 {
                throw "No VPN perms yet"
            }
            if config.leaseVip4.isEmpty {
                throw "No vip4 is set"
            }
            if config.devicePrivateKey.isEmpty {
                throw "No privateKey is set"
            }
            if config.leaseVip4.isEmpty && config.leaseVip6.isEmpty {
                throw "No vip4/vip6 is set for lease"
            }
            if config.gatewayPublicKey.isEmpty {
                throw "No gateway is set"
            }
            return manager
        }
        // Modify tunnel configuration
        .flatMap { manager in
            let dns = self.getUserDnsIp(config.deviceTag)
            BlockaLogger.v("WgWgService", "setConfig: gateway: \(config.gatewayNiceName), tag: \(config.deviceTag), dns: \(dns)")

            var interface = InterfaceConfiguration(privateKey: PrivateKey(base64Key: config.devicePrivateKey)!)
            interface.dns = [DNSServer(from: dns)!]
            interface.addresses = [
                IPAddressRange(from: "\(config.leaseVip4)/32"),
                IPAddressRange(from: "\(config.leaseVip6)/64"),
            ].filter { it in it != nil }.map { it in it! }

            var peer = PeerConfiguration(publicKey: PublicKey(base64Key: config.gatewayPublicKey)!)
            peer.endpoint = Endpoint(from: "\(config.gatewayIpv4):51820")
//            peer.allowedIPs = [
//                IPAddressRange(from: "0.0.0.0/0")!,
//                IPAddressRange(from: "::/0")!,
//            ]
            peer.allowedIPs = self.localIps.map { it in IPAddressRange(from: it)! }
            peer.persistentKeepAlive = 120

            let tunnelConfiguration = TunnelConfiguration(name: "Blokada+ (\(config.gatewayNiceName))", interface: interface, peers: [peer])

            let container = manager.tunnel(at: 0)
            return Future<TunnelsManager, Error> { promise in
                manager.modify(tunnel: container, tunnelConfiguration: tunnelConfiguration, onDemandOption: .anyInterface(.anySSID), shouldEnsureOnDemandEnabled: true) { error -> Void in
                    guard error == nil else {
                        return promise(.failure("setConfig: could not modify tunnel".cause(error)))
                    }

                    return promise(.success(manager))
                }
            }
//            .map { manager in
//                BlockaLogger.w("WgService", "Hack restart")
//                container.status = .restarting
//                (container.tunnelProvider.connection as? NETunnelProviderSession)?.stopTunnel()
//                return manager
//            }
            .eraseToAnyPublisher()
        }
        .map { _ in true }
        .eraseToAnyPublisher()
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
        return wgStateHot.filter { $0.isReady() }.first()
        .flatMap { state -> AnyPublisher<Ignored, Error> in
            // VPN already started, ignore
            if state == .activated {
                self.writeWgState.send(.activated)
                return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            return self.getManager()
            .tryMap { manager -> TunnelsManager in
                if manager.numberOfTunnels() == 0 {
                    throw "No VPN perms yet"
                }
                return manager
            }
            // Enable on-demand
            .flatMap { manager -> AnyPublisher<TunnelsManager, Error> in
                BlockaLogger.v("WgService", "Enabling on-demand")
                return Future<TunnelsManager, Error> { promise in
                    manager.setOnDemandEnabled(true, on: manager.tunnel(at: 0)) { error in
                        guard error == nil else {
                            return promise(.failure("startVpn: could not enable on-demand".cause(error)))
                        }

                        return promise(.success(manager))
                    }
                }
                .eraseToAnyPublisher()
            }
            // Actually start VPN
            .tryMap { manager -> Ignored in
                BlockaLogger.v("WgService", "Starting tunnel")
                manager.startActivation(of: manager.tunnel(at: 0))
                return true
            }
            .delay(for: 0.5, scheduler: self.bgQueue)
            //.map { _ in self.queryWgState() }
            .map { _ in true }
            // Wait for completion or timeout
            .flatMap { _ in
                Publishers.Merge(
                    // Wait until active state is reported
                    self.wgStateHot.filter { $0 == .activated }.first().tryMap { _ in true }
                    .eraseToAnyPublisher(),

                    // Also make a timeout
                    Just(true)
                    .delay(for: 3.0, scheduler: self.bgQueue)
                    .flatMap { _ in self.wgStateHot.first() }
                    .tryMap { state -> Ignored in
                        if state != .activated {
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
        return wgStateHot.filter { $0.isReady() }.first()
        .flatMap { state -> AnyPublisher<Ignored, Error> in
            // VPN already stopped, ignore
            if state == .deactivated { // TODO: paused?
                self.writeWgState.send(.deactivated)
                return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            return self.getManager()
            // Disable on-demand
            .flatMap { manager in
                BlockaLogger.v("WgService", "Disabling on-demand")
                return Future<TunnelsManager, Error> { promise in
                    manager.setOnDemandEnabled(false, on: manager.tunnel(at: 0)) { error in
                        guard error == nil else {
                            return promise(.failure("stopVpn: could not disable on-demand".cause(error)))
                        }
                        
                        return promise(.success(manager))
                    }
                }
            }
            // Actually stop VPN
            .tryMap { manager -> Ignored in
                BlockaLogger.v("WgService", "Stopping tunnel")
                manager.startDeactivation(of: manager.tunnel(at: 0))
                return true
            }
            // Wait for completion or timeout
            .flatMap { _ in
                Publishers.Merge(
                    // Wait until inactive state is reported
                    self.wgStateHot.filter { $0 == .deactivated }.first().tryMap { _ in true }
                    .eraseToAnyPublisher(),

                    // Also make a timeout
                    Just(true)
                    .delay(for: 15.0, scheduler: self.bgQueue)
                    .flatMap { _ in self.wgStateHot.first() }
                    .tryMap { state -> Ignored in
                        if state == .activated {
                            //throw "stopvpn timeout"
                            // Somethings up with the wg state callback
                            self.writeWgState.send(.deactivated)
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
            //.map { _ in self.queryWgState() }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func createVpnProfile() -> AnyPublisher<Ignored, Error> {
        BlockaLogger.v("WgService", "Creating new VPN profile")
        return getManager()
        // Remove existing tunnel if any
        .flatMap { manager -> AnyPublisher<TunnelsManager, Error> in
            if manager.numberOfTunnels() > 0 {
                return Future<TunnelsManager, Error> { promise in
                    manager.remove(tunnel: manager.tunnel(at: 0)) { error -> Void in
                        if let error = error {
                            return promise(.failure("createVpnProfile: could not remove".cause(error)))
                        }
                        
                        return promise(.success(manager))
                    }
                }
                .eraseToAnyPublisher()
            } else {
                return Just(manager).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
        }
        // Add new empty tunnel configuration (will be replaced before starting)
        .flatMap { manager -> AnyPublisher<TunnelsManager, Error> in
            let key = PrivateKey()
            var interface = InterfaceConfiguration(privateKey: key)
            var peer = PeerConfiguration(publicKey: key.publicKey)
            let tunnelConfiguration = TunnelConfiguration(name: "Blokada+ (...)", interface: interface, peers: [peer])

            return Future<TunnelsManager, Error> { promise in
                manager.add(tunnelConfiguration: tunnelConfiguration) { result -> Void in
                    switch result {
                    case .success(_):
                        return promise(.success(manager))
                    case .failure(let error):
                        return promise(.failure("createVpnProfile: could not add".cause(error)))
                    }
                }
            }
            .eraseToAnyPublisher()
        }
        .map { _ in
            self.writePerms.send(true)
            return true
        }
        .eraseToAnyPublisher()
    }

    func changePause(until: Date? = nil) -> AnyPublisher<Ignored, Error> {
        // No timer support, just pause or unpause
        if until == nil {
            return startVpn()
        } else {
            return stopVpn()
        }
    }

    func getStatePublisher() -> AnyPublisher<VpnStatus, Never> {
        return wgStateHot
    }
    
    func getPermsPublisher() -> AnyPublisher<Granted, Never> {
        return permsHot
    }

    func checkPerms() {
        checkPermsT.send()
    }

    func onCheckPerms() {
        checkPermsT.setTask { _ in Just(true)
            .flatMap { _ in self.getManager() }
            .map { manager in
                let enabled = manager.numberOfTunnels() > 0
                print("VPN perms are: \(enabled)")
                return enabled
            }
            .map { it in
                self.writePerms.send(it)
                return it
            }
            // Do a second check after a while because of some weird bug misreporting
            .delay(for: 2, scheduler: self.bgQueue)
            .flatMap { _ in self.getManager() }
            .map { manager in
                let enabled = manager.numberOfTunnels() > 0
                print("VPN perms are (second check): \(enabled)")
                return enabled
            }
            .map { it in
                self.writePerms.send(it)
                return it
            }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
    }

    func refreshOnForeground() {
        checkPerms()
        tunnelsManager.value?.refreshStatuses()
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

    private func onPermsGranted_startMonitoringWg() {
        permsHot
        .sink(onValue: { granted in
            if granted {
                // Calling startMonitoringWg several times is ok
                //self.startMonitoringWg()
            } else {
                // Emit disconnected (fresh app install, or perms rejected)
                BlockaLogger.v("WgService", "No perms, emitting disconnected")
                self.writeWgState.send(.deactivated)
            }
            
        })
        .store(in: &cancellables)
    }
    
    func makeProtectedRequest(url: String, method: String, body: String) -> AnyPublisher<String, Error> {
        let request = [
            NetworkCommand.request.rawValue, url, method, ":body:", body
        ].joined(separator: " ")
        return sendWgMessage(msg: request)
    }

    private func sendWgMessage(msg: String) -> AnyPublisher<String, Error> {
        // Wait until NETX is initialized before any requests
        return writeWgState.first()
        .flatMap { _ in self.getManager() }
        // Actually get the iOS manager object
        .tryMap { manager -> NETunnelProviderManager in
            return manager.tunnel(at: 0).tunnelProvider
        }
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
                                return promise(.failure("sendWgMessage: got a nil reply back for command".cause(msg)))
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
                        return promise(.failure("sendWgMessage: sending message failed".cause(error)))
                    }
                }
                .eraseToAnyPublisher(),

                // Also make a timeout
                Just(true)
                .delay(for: 5.0, scheduler: self.bgQueue)
                .tryMap { state -> String in
                    throw "WG message timeout"
                }
                .eraseToAnyPublisher()
            )
            .first() // Whatever comes first: a response, or the timeout throwing
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    // Returns a manager ref, or errors out if not available
    private func getManager() -> AnyPublisher<TunnelsManager, Error> {
        if let m = tunnelsManager.value {
            return Just(m).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return Fail(error: "No TunnelsManager available")
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

}
