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
import NetworkExtension

class NetworkService {

    static let shared = NetworkService()

    private let log = Logger("Network")
    let httpClient: OpaquePointer?
    private let configurationFilteringOnly = "No Server"

    var onStatusChanged = { (status: NetworkStatus) in }

    private var internalStatusObserver = Atomic<NSObjectProtocol?>(nil)
    private var startingCallback = Atomic<Callback<Void>?>(nil)
    private var stoppingCallback = Atomic<Callback<Void>?>(nil)
    private var started = Atomic<Bool>(false)
    private var attemptId = Atomic<Int>(0)
    private var attempts = Atomic<Int>(0)

    private init() {
        self.httpClient = api_new(10, BlockaApiService.userAgent())
    }

    func updateConfig(lease: Lease?, gateway: Gateway?, done: @escaping Callback<Void>) {
        onBackground {
            self.getManager { error, manager in
                onMain {
                    guard error == nil else {
                        return done(error, nil)
                    }

                    self.saveConfig(manager!, lease, gateway) { error, _ in
                        onMain {
                            return done(error, nil)
                        }
                    }
                }
            }
        }
    }

    private func saveConfig(_ manager: NETunnelProviderManager, _ lease: Lease?, _ gateway: Gateway?,
            done: @escaping Callback<Void>) { onBackground {
        let dns = Dns.load()

        self.log.v("saveConfig: gateway: \(gateway?.niceName()), dns: \(dns.label)")

        let protoConfig = NETunnelProviderProtocol()
        protoConfig.providerBundleIdentifier = "net.blocka.app.engine"
        protoConfig.serverAddress = gateway == nil ? self.configurationFilteringOnly : gateway!.niceName()
        protoConfig.username = ""

        var plusIps = dns.ips
        if dns.plusIps != nil {
            self.log.w("Using plusMode specific DNS IPs")
            plusIps = dns.plusIps!
        }

        if let l = lease, let g = gateway {
            protoConfig.providerConfiguration = [
                "mode": "plus",
                "userAgent": BlockaApiService.userAgent(),
                "privateKey": Config.shared.privateKey(),
                "gatewayId": g.public_key,
                "ipv4": g.ipv4,
                "ipv6": g.ipv6,
                "port": String(g.port),
                "vip4": l.vip4,
                "vip6": l.vip6,
                "dnsIps": dns.ips.joined(separator: ","),
                "plusDnsIps": plusIps.joined(separator: ","),
                "dnsName": dns.name,
                "dnsPath": dns.path
            ]
        } else {
            protoConfig.providerConfiguration = [
                "mode": "libre",
                "userAgent": BlockaApiService.userAgent(),
                "dnsIps": dns.ips.joined(separator: ","),
                "plusDnsIps": plusIps.joined(separator: ","),
                "dnsName": dns.name,
                "dnsPath": dns.path
            ]
        }

        manager.protocolConfiguration = protoConfig
        manager.localizedDescription = "BLOKADA"
        manager.isEnabled = true

        manager.saveToPreferences() { error in onBackground {
            guard error == nil else {
                self.log.e("saveConfig: could not save configuration".cause(error))
                return done(error, nil)
            }

            return done(nil, nil)
        }}
    }}

    private func startMonitoringSession(_ connection: NETunnelProviderSession) {
        if let observer = self.internalStatusObserver.value {
            NotificationCenter.default.removeObserver(observer)
        }

        let listener = self.newStatusListener(onConnectedOrDisconnected: { connected in
            self.log.v("NETX connected: \(connected)")
            self.started.value = connected

            if let callback = self.startingCallback.value {
                if connected {
                    self.startingCallback.value = nil
                    callback(nil, nil)
                }
            }

            if let callback = self.stoppingCallback.value {
                if !connected {
                    self.stoppingCallback.value = nil
                    callback(nil, nil)
                }
            }

            if connected {
                self.queryStatus { _, status in
                    self.onStatusChanged(status ?? NetworkStatus.disconnected())
                }
            } else {
                self.onStatusChanged(NetworkStatus.disconnected())
            }
        }, onProgress: { status in
            self.log.v("NETX progress: \(status)")
            self.onStatusChanged(NetworkStatus.inProgress())
        }, fail: { error in
            self.log.v("NETX error: \(error)")
            //self.started.value = false
            self.onStatusChanged(NetworkStatus.disconnected())
        })

        self.internalStatusObserver.value = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NEVPNStatusDidChange,
            object: connection,
            queue: OperationQueue.main,
            using: listener
        )
    }

    func startTunnel(done: @escaping Callback<Void>) { onBackground {
        self.log.v("startTunnel")

        self.getManager { error, manager in onBackground {
            guard error == nil else {
                return onMain {
                    self.onStatusChanged(NetworkStatus.disconnected())
                    done(error, nil)
                }
            }

            guard let manager = manager else {
                return onMain {
                    self.onStatusChanged(NetworkStatus.disconnected())
                    done("No manager", nil)
                }
            }

            manager.isEnabled = true
            manager.isOnDemandEnabled = true
            manager.saveToPreferences() { error in onBackground {
                guard error == nil else {
                    self.log.e("startTunnel: could not enable vpn profile".cause(error))
                    return done(error, nil)
                }

                do {
                    let connection = manager.connection as! NETunnelProviderSession
                    //self.startMonitoringSession(connection)

                    if connection.status == NEVPNStatus.connected {
                        self.log.v("startTunnel: already connected")
                        self.onStatusChanged(NetworkStatus(active: true, inProgress: false, gatewayId: nil, pauseSeconds: 0))
                        return done(nil, nil)
                    }

                    self.startingCallback.value = done
                    let id = self.attemptId.value + 1
                    self.attemptId.value = id
                    try connection.startVPNTunnel()
                    self.log.v("startTunnel: starting")

                    // A timeout and retry
                    bgThread.asyncAfter(deadline: .now() + 6) {
                        if self.attemptId.value == id && !self.started.value {
                            let attempt = self.attempts.value
                            if attempt < 1 {
                                self.attempts.value = attempt + 1
                                self.log.w("startTunnel: not started, trying again: \(attempt)")
                                return self.startTunnel(done: done)
                            } else {
                                self.attempts.value = 0
                                self.startingCallback.value = nil
                                self.log.e("startTunnel: retry attempts limit reached, removing VPN profile")
                                return onMain {
                                    self.onStatusChanged(NetworkStatus.disconnected())
                                    manager.removeFromPreferences(completionHandler: nil)
                                    done("retry attempts limit reached", nil)
                                }
                            }
                        }
                    }
                } catch {
                    self.log.e("startTunnel: failed".cause(error))
                    self.startingCallback.value = nil
                    onMain {
                        self.onStatusChanged(NetworkStatus.disconnected())
                        done(error, nil)
                    }
                }
            }}
        }}
    }}

    func stopTunnel(done: @escaping Callback<Void>) { onBackground {
        self.log.v("stopTunnel")

        self.getManager { error, manager in
            guard let manager = manager else {
                self.log.e("stopTunnel: could not get the manager")
                return onMain { done("could not stop tunnel", nil) }
            }
            guard error == nil else {
                return onMain { done(error, nil) }
            }

            let connection = manager.connection as! NETunnelProviderSession
            if connection.status == NEVPNStatus.disconnected {
                self.log.v("stopTunnel: already stopped")
                self.onStatusChanged(NetworkStatus(active: false, inProgress: false, gatewayId: nil, pauseSeconds: 0))
                return onMain { done(nil, nil) }
            }

            self.stoppingCallback.value = done
            let id = self.attemptId.value + 1
            self.attemptId.value = id
            self.attempts.value = 0

            manager.isOnDemandEnabled = false
            manager.saveToPreferences() { error in onBackground {
                guard error == nil else {
                    self.log.e("stopTunnel: could not disable on demand connect".cause(error))
                    return onMain { done(error, nil) }
                }

                connection.stopVPNTunnel()
                self.log.v("stopTunnel: stopping")

                // A timeout
                bgThread.asyncAfter(deadline: .now() + 15) {
                    if self.attemptId.value == id && self.started.value {
                        self.stoppingCallback.value = nil
                        self.log.e("stopTunnel: timeout waiting to stop")
                        return onMain { done(nil, nil) }
                    }
                }
            }}
        }
    }}

    func queryStatus(done: @escaping Callback<NetworkStatus>) { onBackground {
        self.getManager { error, manager in
            guard error == nil else {
                return onMain { done(error, nil) }
            }

            guard let connection = manager?.connection as? NETunnelProviderSession else {
                return onMain { done("no connection", nil) }
            }

            self.startMonitoringSession(connection)

            var gatewayId: String? = nil
            if let server = (manager?.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration?["gatewayId"] {
                gatewayId = server as? String
            }

            self.sendMessage(msg: "report") { error, response in
                var pauseSeconds = 0
                if let seconds = response, response != "off" {
                    pauseSeconds = Int(seconds) ?? 0
                }

                let status = NetworkStatus(
                    active: connection.status == NEVPNStatus.connected && manager!.isEnabled,
                    inProgress: [NEVPNStatus.connecting, NEVPNStatus.disconnecting, NEVPNStatus.reasserting].contains(connection.status),
                    gatewayId: gatewayId,
                    pauseSeconds: pauseSeconds
                )

                self.started.value = status.active
                onMain { done(nil, status) }
            }
        }
    }}

    func directRequest(url: String, method: String, body: String, done: @escaping Callback<String>) {
        guard let httpClient = self.httpClient else {
            return done("httpClient was not initialized", nil)
        }
        onBackground {
            let result = api_request(httpClient, method, url, body)
            defer { api_response_free(result) }
            if let res = result {
                if let error = res.pointee.error {
                    let err = String(cString: error)
                    return onMain { done(err, nil) }
                }

                if res.pointee.code != 200 {
                    return onMain { done(NetworkError.http(Int(res.pointee.code)), nil) }
                }

                let responseBody = String(cString: res.pointee.body)
                onMain { done(nil, responseBody) }
            } else {
                return onMain { done("No result", nil) }
            }
        }
    }

    func changeGateway(lease: Lease, gateway: Gateway, done: @escaping Callback<String>) {
        onBackground {
            let connect = [
                NetworkCommand.connect.rawValue,
                Config.shared.privateKey(),
                lease.gateway_id,
                gateway.ipv4,
                gateway.ipv6,
                String(gateway.port),
                lease.vip4,
                lease.vip6
            ].joined(separator: " ")
            self.sendMessage(msg: connect) { error, _ in
                guard error == nil else {
                    return onMain {
                        self.onStatusChanged(NetworkStatus(active: true, inProgress: false, gatewayId: nil, pauseSeconds: 0))
                        done(error, nil)
                    }
                }

                self.onStatusChanged(NetworkStatus(active: true, inProgress: false, gatewayId: gateway.public_key, pauseSeconds: 0))
                done(nil, nil)
            }
        }
    }

    func disconnect(done: @escaping Callback<String>) {
        onBackground {
            self.sendMessage(msg: NetworkCommand.disconnect.rawValue) { error, _ in
                self.onStatusChanged(NetworkStatus(active: true, inProgress: false, gatewayId: nil, pauseSeconds: 0))
                done(error, nil)
            }
        }
    }

    func pause(seconds: Int, done: @escaping Callback<String>) {
        onBackground {
            let command = ["pause", String(seconds)].joined(separator: " ")
            self.sendMessage(msg: command, done: done)
        }
    }

    func sendMessage(msg: String, skipReady: Bool = false, done: @escaping Callback<String>) { onBackground {
        if self.started.value || skipReady {
            self.getManager { error, manager in
                guard error == nil else {
                    return onMain { done(error, nil) }
                }

                let data = msg.data(using: String.Encoding.utf8)!
                do {
                    let connection = manager!.connection as! NETunnelProviderSession
                    try connection.sendProviderMessage(data) { (d) in onBackground {
                        guard d != nil else { return onMain {
                            done("sendMessage: got a nil reply back for command: \(msg)", nil)
                        }}

                        let data = String.init(data: d!, encoding: String.Encoding.utf8)!
                        if (data.starts(with: "error: code: ")) {
                            let code = Int(data.components(separatedBy: "error: code: ")[1])!
                            self.log.e("sendMessage: response: \(code)")
                            onMain { done(NetworkError.http(code), nil) }
                        } else if (data.starts(with: "error: ")) {
                            self.log.e("sendMessage: response: ".cause(data))
                            onMain { done(data, nil) }
                        } else {
                            onMain { done(nil, data) }
                        }
                    }}
                } catch {
                    self.log.e("sendMessage: failed to send message \(msg)".cause(error))
                    onMain { done(error, nil) }
                }
            }
        } else { onMain {
            done("sendMessage: provider not ready", nil)
        }}
    }}

    func createVpnProfile(done: @escaping Callback<Void>) {
        onBackground {
            // According to Apple docs we need to call loadFromPreferences at least once
            self.log.v("createVpnProfile: Using new VPN profile")
            let manager = NETunnelProviderManager()
            manager.onDemandRules = [NEOnDemandRuleConnect()]
            manager.loadFromPreferences { error in onBackground {
                guard error == nil else {
                    self.log.e("createVpnProfile: loadFromPreferences failed".cause(error))
                    return onMain { done(error, nil) }
                }

                self.saveConfig(manager, nil, nil) { error, _ in
                    return onMain { done(error, nil) }
                }
            }}
        }
    }

    private func getManager(done: @escaping Callback<NETunnelProviderManager>) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in onBackground {
            guard error == nil else {
                self.log.e("getManager: loadAllFromPreferences failed".cause(error))
                return done(error, nil)
            }

            let managersCount = managers?.count ?? 0
            if (managersCount > 1) {
                self.log.w("getManager: Found more than one VPN profile, deleting others")
                for i in 0..<(managersCount - 1) {
                    managers![i].removeFromPreferences(completionHandler: nil)
                }
            }

            if (managersCount == 0) {
                self.log.w("getManager: No VPN profile")
                return done(CommonError.vpnNoPermissions, nil)
            } else {
                // According to Apple docs we need to call loadFromPreferences at least once
                let manager = managers![managersCount - 1]
                manager.loadFromPreferences { error in onBackground {
                    guard error == nil else {
                        self.log.e("getManager: loadFromPreferences failed".cause(error))
                        return done(error, nil)
                    }

                    return done(nil, manager)
                    }}
            }
        }}
    }

    private func newStatusListener(
        onConnectedOrDisconnected: @escaping (Bool) -> Void,
        onProgress: @escaping (String) -> Void,
        fail: @escaping (Error) -> Void
    ) -> ((Notification) -> Void) {
        return { notification in
            onBackground {
                let connection = notification.object as! NETunnelProviderSession
                switch (connection.status) {
                case NEVPNStatus.connected:
                    onConnectedOrDisconnected(true)
                case NEVPNStatus.connecting:
                    onProgress("connecting")
                case NEVPNStatus.disconnected:
                    onConnectedOrDisconnected(false)
                case NEVPNStatus.disconnecting:
                    onProgress("disconnecting")
                case NEVPNStatus.invalid:
                    fail("invalid")
                case NEVPNStatus.reasserting:
                    onProgress("reasserting")
                default:
                    fail("unknown")
                }
            }
        }
    }
}
