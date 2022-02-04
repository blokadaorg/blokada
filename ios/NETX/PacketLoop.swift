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
import Network
import NetworkExtension

enum LogLevel: UInt32 {
    case NONE = 0
    case INFO
    case DEBUG
    case ALL
};

enum SessionState {
    case NotInitialized
    case IsRecovering(NWUDPSession)
    case WasRecovered(NWUDPSession)
    case IsReady(NWUDPSession)
    case IsInvalid(NWUDPSession)
    case IsCancelling(NWUDPSession)
}

protocol TunnelSessionDelegate: class {
    func createSession() -> NWUDPSession
    func readPacketObjects(completionHandler: @escaping ([NEPacket]) -> Void)
    func writePackets(_ packets: [Data], withProtocols protocols: [NSNumber]) -> Void
    func hasBetterEndpoint(_ session: NWUDPSession) -> Bool
}

func invalidSession(_ session: NWUDPSession) -> Bool {
    switch session.state {
        case .invalid: return true
        case .failed: return true
        case .cancelled: return true
        default: return !session.isViable
    }
}

let maxPacketSize = 1500
let maxDatagrams = 100
let bufferSize = maxPacketSize * maxDatagrams
let sessionQueue = DispatchQueue(label: "session")

class PacketLoop: NSObject {
    var session: SessionState = .NotInitialized
    var sessionObserver: NSKeyValueObservation?
    var sessionTicker: Timer? = nil
    weak var delegate: TunnelSessionDelegate?
    var tunnel: OpaquePointer?
    var wireguardReadBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    var wireguardWriteBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    var wireguardTimerBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxPacketSize)
    var wireguardTicker: Timer? = nil

    // Preallocated data arrays
    var wireguardReadDatagrams = [Data]()
    var wireguardReadPackets = [Data]()
    var wireguardReadPacketProtocols = [NSNumber]()
    var wireguardWriteDatagrams = [Data]()

    func start(privateKey: String, gatewayKey: String, delegate: TunnelSessionDelegate) {
        self.delegate = delegate

        // Main thread is where timers works
        DispatchQueue.main.sync {
            if self.tunnel != nil {
                fatalError("started before stopped")
            }
            self.tunnel = new_tunnel(privateKey, gatewayKey, tunnel_log, LogLevel.DEBUG.rawValue)

            // observing doesn't work so we poll. https://github.com/apple/swift/pull/20757
            self.startSessionTicker()
            self.startWireguardTicker()

            // Egress to the gateway
            self.delegate?.readPacketObjects(completionHandler: self.handleOutboundPackets)
        }
    }

    func startSessionTicker() {
        if sessionTicker != nil {
            NELogger.e("PacketLoop: startSessionTicker when ticker is already running")
            return
        }
        self.sessionTicker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard let delegate = self.delegate else { return }
            sessionQueue.sync {
                if self.sessionTicker == nil {
                    return
                }
                switch self.session {
                case .NotInitialized:
                    let session = delegate.createSession()
                    // TODO: move setReadHandler to createSession()
                    session.setReadHandler(self.handleInboundPackets, maxDatagrams: maxDatagrams)
                    self.session = .IsRecovering(session)
                case .IsRecovering(let session):
                    if session.state == .ready {
                        self.session = .WasRecovered(session)
                        break
                    }
                    // Try again
                    self.session = .IsInvalid(session)
                case .WasRecovered(let session):
                    DispatchQueue.main.async {
                        self.handshakeNow()
                    }
                    self.session = .IsReady(session)
                    NELogger.v("PacketLoop: recovered session with endpoint: \(session.endpoint.description)")
                case .IsReady(let session):
                    if invalidSession(session) {
                        self.session = .IsInvalid(session)
                        break
                    }
                    if session.hasBetterPath {
                        NELogger.v("PacketLoop: upgrade session")
                        let session = NWUDPSession(upgradeFor: session)
                        session.setReadHandler(self.handleInboundPackets, maxDatagrams: maxDatagrams)
                        self.session = .IsRecovering(session)
                        break
                    }

                    // Work around for not being able to specify multiple endpoints.
                    // If wifi doesn't support IPv6 while mobile does, and that's our current stack
                    // we won't switch to wifi without this.
                    if delegate.hasBetterEndpoint(session) {
                        NELogger.w("PacketLoop: switch to cheaper endpoint path")
                        self.session = .IsInvalid(session)
                    }
                case .IsInvalid(let session):
                    NELogger.v("PacketLoop: cancel invalid session")
                    session.cancel()
                    self.session = .IsCancelling(session)
                case .IsCancelling(let session):
                    if session.state == .cancelled {
                        NELogger.v("PacketLoop: replace invalid session")
                        let session = delegate.createSession()
                        session.setReadHandler(self.handleInboundPackets, maxDatagrams: maxDatagrams)
                        self.session = .IsRecovering(session)
                    }
                }
            }
        }
    }

    func startWireguardTicker() {
        if wireguardTicker != nil {
            NELogger.e("PacketLoop: startWireguardTicker when ticker is already running")
            return
        }
        self.wireguardTicker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard let tunnel = self.tunnel else { return }

            if self.wireguardTicker == nil {
                return
            }
            let res = wireguard_tick(tunnel, self.wireguardTimerBuffer, UInt32(maxPacketSize))
            switch res.op {
            case WRITE_TO_NETWORK:
                let packet = Data(bytesNoCopy: self.wireguardTimerBuffer, count: Int(res.size), deallocator: .none)
                self.sendDatagrams(datagrams: [packet])
                NELogger.v("PacketLoop: wireguard_tick")
            case WIREGUARD_DONE:
                break
            case WIREGUARD_ERROR:
                NELogger.e("PacketLoop: WIREGUARD_ERROR in wireguard_tick: \(res.size)")
            default:
                NELogger.e("PacketLoop: Unexpected return type in wireguard_tick: \(res.op)")
            }
        }
    }

    // Stop is used to clean things up as deinit is unreliable. We also keep buffers alive in between to avoid
    // race conditions with packet reading/writing completion handlers which might complete after we deinit.
    func stop() {
        sessionQueue.sync {
            if let tunnel = tunnel {
                tunnel_free(tunnel)
            }
            tunnel = nil
            sessionTicker?.invalidate()
            sessionTicker = nil
            session = .NotInitialized
            wireguardTicker?.invalidate()
            wireguardTicker = nil

            // Clear pending packets
            wireguardReadDatagrams = [Data]()
            wireguardReadPackets = [Data]()
            wireguardReadPacketProtocols = [NSNumber]()
            wireguardWriteDatagrams = [Data]()
        }
    }

    func handleOutboundPackets(_ packets: [NEPacket]) {
        guard let tunnel = self.tunnel else { return }

        var offset: UInt = 0
        for packet in packets {
            if offset + UInt(maxPacketSize) > bufferSize {
                // Flush if might not have enough space
                sendDatagrams(datagrams: self.wireguardWriteDatagrams)
                self.wireguardWriteDatagrams.removeAll(keepingCapacity: true)
                offset = 0
            }

            // We encapsulate as many packets as we can into the wireguardWriteBuffer
            let writeBuff = self.wireguardWriteBuffer.advanced(by: Int(offset))

            let res = packet.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> wireguard_result in
                let dataPtr = ptr.baseAddress?.bindMemory(to: UInt8.self, capacity: packet.data.count)
                return wireguard_write(tunnel, dataPtr, UInt32(packet.data.count), writeBuff, UInt32(maxPacketSize))
            }

            switch res.op {
            case WRITE_TO_NETWORK:
                self.wireguardWriteDatagrams.append(Data(bytesNoCopy: writeBuff, count: Int(res.size), deallocator: .none))
                offset += res.size
            case WIREGUARD_DONE:
                break
            case WIREGUARD_ERROR:
                NELogger.e("PacketTunnelProvider: WIREGUARD_ERROR in wireguard_write: \(res.size)")
            default:
                NELogger.e("PacketTunnelProvider: Unexpected return type: \(res.op)")
            }
        }

        if self.wireguardWriteDatagrams.count > 0 {
            // Send
            self.sendDatagrams(datagrams: self.wireguardWriteDatagrams)
            self.wireguardWriteDatagrams.removeAll(keepingCapacity: true)
        }

        // Extra wrapping due to memory leak while doing recursive calls
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.readPacketObjects(completionHandler: self.handleOutboundPackets)
        }
    }

    func handleInboundPackets(datagrams: [Data]?, err: Error?) {
        guard let datagrams = datagrams else {
            if err != nil /* && !self.reconnecting.value */ {
                NELogger.e("PacketTunnelProvider: error while reading datagrams: \(String(describing: err))")
                return // self.handleUDPError(err: err!)
            }
            return
        }
        guard let tunnel = self.tunnel else { return }

        var offset: UInt = 0
        var flushQueue = false

        // This is the main loop
        for wireguardDatagram in datagrams {
            // Check if we ran out of space and need to flush
            if offset + UInt(maxPacketSize) >= bufferSize {
                flushReadStructs()
                offset = 0
            }

            let readBuff = self.wireguardReadBuffer.advanced(by: Int(offset))

            let res = wireguardDatagram.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> wireguard_result in
                let dataPtr = ptr.baseAddress?.bindMemory(to: UInt8.self, capacity: Int(maxPacketSize))
                return wireguard_read(tunnel, dataPtr, UInt32(wireguardDatagram.count), readBuff, UInt32(maxPacketSize))
            }

            switch res.op {
            case WIREGUARD_DONE:
                break
            case WRITE_TO_NETWORK:
                self.wireguardReadDatagrams.append(Data(bytesNoCopy: readBuff, count: Int(res.size), deallocator: .none))
                offset += res.size
                flushQueue = true
            case WRITE_TO_TUNNEL_IPV4, WRITE_TO_TUNNEL_IPV6:
                let family = (res.op == WRITE_TO_TUNNEL_IPV4) ? AF_INET : AF_INET6
                self.wireguardReadPackets.append(Data(bytesNoCopy: readBuff, count: Int(res.size), deallocator: .none))
                self.wireguardReadPacketProtocols.append(NSNumber(value: family))
                offset += res.size
            case WIREGUARD_ERROR:
                NELogger.e("PacketTunnelProvider: WIREGUARD_ERROR in wireguard_read: \(res.size)")
            default:
                NELogger.e("PacketTunnelProvider: Unexpected return type: \(res.op)")
            }
        }

        // If wireguard library wants to send prior pending packets to network, handle that case
        // and repeat calling wireguard_read() until WIREGUARD_DONE or error is returned.
        if flushQueue {
            if offset + UInt(maxPacketSize) >= bufferSize {
                flushReadStructs()
                offset = 0
            }

            let readBuff = self.wireguardReadBuffer.advanced(by: Int(offset))
            flushLoop: while true {
                let res = wireguard_read(tunnel, nil, 0, readBuff, UInt32(maxPacketSize))
                switch res.op {
                case WRITE_TO_NETWORK:
                    self.wireguardReadDatagrams.append(Data(bytesNoCopy: readBuff, count: Int(res.size), deallocator: .none))
                    offset += res.size
                case WIREGUARD_DONE:
                    break flushLoop
                case WIREGUARD_ERROR:
                    NELogger.e("PacketTunnelProvider: WIREGUARD_ERROR in repeat wireguard_read: \(res.size)")
                    break flushLoop
                default:
                    NELogger.e("PacketTunnelProvider: Unexpected return type: \(res.op)")
                    break flushLoop
                }
            }
        }

        flushReadStructs()
    }

    func flushReadStructs() {
        if self.wireguardReadPackets.count > 0 {
            self.delegate?.writePackets(self.wireguardReadPackets, withProtocols: self.wireguardReadPacketProtocols)
        }

        if self.wireguardReadDatagrams.count > 0 {
            self.sendDatagrams(datagrams: self.wireguardReadDatagrams)
        }

        self.wireguardReadPackets.removeAll(keepingCapacity: true)
        self.wireguardReadDatagrams.removeAll(keepingCapacity: true)
        self.wireguardReadPacketProtocols.removeAll(keepingCapacity: true)
    }

    func sleep() {
        NELogger.v("PacketLoop: sleep")
        sessionQueue.sync {
            sessionTicker?.invalidate()
            sessionTicker = nil
            wireguardTicker?.invalidate()
            wireguardTicker = nil
            if case let SessionState.IsReady(session) = session {
                session.cancel()
            }
            self.session = .NotInitialized

            // Clear pending packets
            wireguardReadDatagrams = [Data]()
            wireguardReadPackets = [Data]()
            wireguardReadPacketProtocols = [NSNumber]()
            wireguardWriteDatagrams = [Data]()
        }
    }

    func wake() {
        NELogger.v("PacketLoop: wake")
        // Main thread is where timers works
        DispatchQueue.main.sync {
            startSessionTicker()
            startWireguardTicker()
        }
    }
    
    func handshakeNow() {
        guard let tunnel = tunnel else { return }
        let handshake = UnsafeMutablePointer<UInt8>.allocate(capacity: maxPacketSize)
        defer { handshake.deallocate() }

        let res = wireguard_force_handshake(tunnel, handshake, UInt32(maxPacketSize))
        switch res.op {
        case WRITE_TO_NETWORK:
            let packet = Data(bytesNoCopy: handshake, count: Int(res.size), deallocator: .none)
            self.sendDatagrams(datagrams: [packet])
            NELogger.v("PacketLoop: force handshake")
        case WIREGUARD_DONE:
            break
        case WIREGUARD_ERROR:
            NELogger.e("PacketLoop: WIREGUARD_ERROR in handshakeNow: \(res.size)")
        default:
            NELogger.e("PacketLoop: Unexpected return type in handshakeNow: \(res.op)")
        }
    }

    func sendDatagrams(datagrams: [Data]) {
        if (datagrams.count == 0) {
            NELogger.e("PacketLoop: tried to send 0 datagrams")
            return
        }

        // writeMultipleDatagrams says we should wait for it to return before issuing
        // another write. Thus we use a serial queue.
        sessionQueue.sync {
            switch self.session {
            case .IsReady(let session):
                if session.state != .ready || !session.isViable {
                    break
                }
                session.writeMultipleDatagrams(datagrams) { err in
                    if err != nil {
                        NELogger.e("PacketLoop: Error sending packets: \(String(describing: err))")
                        self.session = .IsInvalid(session)
                    }
                }
            default:
                // No current session
                break
            }
        }
    }
}

private func tunnel_log(msg: UnsafePointer<Int8>?) {
    guard let msg = msg else { return }
    let str = String(cString: msg)
    NELogger.v("PacketLoop: Tunnel: \(str)")
}
