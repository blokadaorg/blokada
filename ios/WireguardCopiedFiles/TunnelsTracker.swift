// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

// Keeps track of tunnels and informs the following objects of changes in tunnels:
//   - WgService

import Foundation
import Combine

class TunnelsTracker {

    private var tunnelsManager: TunnelsManager
    private var tunnelStatusObservers = [AnyObject]()
    private(set) var currentTunnel: TunnelContainer? {
        didSet {
            
        }
    }

    var onTunnelState = { (status: NetworkStatus) in }

    init(tunnelsManager: TunnelsManager) {
        self.tunnelsManager = tunnelsManager
        currentTunnel = tunnelsManager.tunnelInOperation()

        for index in 0 ..< tunnelsManager.numberOfTunnels() {
            let tunnel = tunnelsManager.tunnel(at: index)
            let statusObservationToken = observeStatus(of: tunnel)
            tunnelStatusObservers.insert(statusObservationToken, at: index)
        }

        tunnelsManager.tunnelsListDelegate = self
        tunnelsManager.activationDelegate = self
    }

    func observeStatus(of tunnel: TunnelContainer) -> AnyObject {
        return tunnel.observe(\.status) { [weak self] tunnel, _ in
            guard let self = self else { return }
            if tunnel.status == .deactivating || tunnel.status == .inactive {
                if self.currentTunnel == tunnel {
                    self.currentTunnel = self.tunnelsManager.tunnelInOperation()
                }
            } else {
                self.currentTunnel = tunnel
            }
        }
    }
}

extension TunnelsTracker: TunnelsManagerActivationDelegate {
    func tunnelActivationAttemptFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationAttemptError) {
        switch (error) {
            case .tunnelIsNotInactive:
                BlockaLogger.v("TunnelsTracker", "tun: \(tunnel.name), is active")
                onTunnelState(NetworkStatus(
                    active: true, inProgress: false,
                    gatewayId: tunnel.tunnelConfiguration!.peers.first!.publicKey.base64Key,
                    pauseSeconds: 0
                ))
            default:
                BlockaLogger.e("TunnelsTracker", "tun: \(tunnel.name), activation attempt fail: \(error)")
                onTunnelState(NetworkStatus.disconnected())
        }
    }

    func tunnelActivationAttemptSucceeded(tunnel: TunnelContainer) {
        BlockaLogger.v("TunnelsTracker", "tun: \(tunnel.name), activation attempt succeeded")
        onTunnelState(NetworkStatus(
            active: true, inProgress: false,
            gatewayId: tunnel.tunnelConfiguration!.peers.first!.publicKey.base64Key,
            pauseSeconds: 0
        ))
    }

    func tunnelActivationFailed(tunnel: TunnelContainer, error: TunnelsManagerActivationError) {
        BlockaLogger.e("TunnelsTracker", "tun: \(tunnel.name), activation fail: \(error)")
        onTunnelState(NetworkStatus.disconnected())
    }

    func tunnelActivationSucceeded(tunnel: TunnelContainer) {
        BlockaLogger.v("TunnelsTracker", "tun: \(tunnel.name), activation succeeded")
        onTunnelState(NetworkStatus(
            active: true, inProgress: false,
            gatewayId: tunnel.tunnelConfiguration!.peers.first!.publicKey.base64Key,
            pauseSeconds: 0
        ))
    }

    func tunnelDeactivated(tunnel: TunnelContainer) {
        BlockaLogger.v("TunnelsTracker", "tun: \(tunnel.name), deactivated")
        onTunnelState(NetworkStatus.disconnected())
    }
}

extension TunnelsTracker: TunnelsManagerListDelegate {
    func tunnelAdded(at index: Int) {
        let tunnel = tunnelsManager.tunnel(at: index)
        if tunnel.status != .deactivating && tunnel.status != .inactive {
            self.currentTunnel = tunnel
        }
        let statusObservationToken = observeStatus(of: tunnel)
        tunnelStatusObservers.insert(statusObservationToken, at: index)

        // nothing for now
    }

    func tunnelModified(at index: Int) {
        // nothing for now
    }

    func tunnelMoved(from oldIndex: Int, to newIndex: Int) {
        let statusObserver = tunnelStatusObservers.remove(at: oldIndex)
        tunnelStatusObservers.insert(statusObserver, at: newIndex)

        // nothing for now
    }

    func tunnelRemoved(at index: Int, tunnel: TunnelContainer) {
        tunnelStatusObservers.remove(at: index)

        // nothing for now
    }
}
