// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation

class RecentTunnelsTracker {

    private static let keyRecentlyActivatedTunnelNames = "recentlyActivatedTunnelNames"
    private static let maxNumberOfTunnels = 10

    private static var userDefaults: UserDefaults? {
        guard let appGroupId = FileManager.appGroupId else {
            wg_log(.error, staticMessage: "Cannot obtain app group ID from bundle for tracking recently used tunnels")
            return nil
        }
        guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
            wg_log(.error, staticMessage: "Cannot obtain shared user defaults for tracking recently used tunnels")
            return nil
        }
        return userDefaults
    }

    static func handleTunnelActivated(tunnelName: String) {
        guard let userDefaults = RecentTunnelsTracker.userDefaults else { return }
        var recentTunnels = userDefaults.stringArray(forKey: keyRecentlyActivatedTunnelNames) ?? []
        if let existingIndex = recentTunnels.firstIndex(of: tunnelName) {
            recentTunnels.remove(at: existingIndex)
        }
        recentTunnels.insert(tunnelName, at: 0)
        if recentTunnels.count > maxNumberOfTunnels {
            recentTunnels.removeLast(recentTunnels.count - maxNumberOfTunnels)
        }
        userDefaults.set(recentTunnels, forKey: keyRecentlyActivatedTunnelNames)
    }

    static func handleTunnelRemoved(tunnelName: String) {
        guard let userDefaults = RecentTunnelsTracker.userDefaults else { return }
        var recentTunnels = userDefaults.stringArray(forKey: keyRecentlyActivatedTunnelNames) ?? []
        if let existingIndex = recentTunnels.firstIndex(of: tunnelName) {
            recentTunnels.remove(at: existingIndex)
            userDefaults.set(recentTunnels, forKey: keyRecentlyActivatedTunnelNames)
        }
    }

    static func handleTunnelRenamed(oldName: String, newName: String) {
        guard let userDefaults = RecentTunnelsTracker.userDefaults else { return }
        var recentTunnels = userDefaults.stringArray(forKey: keyRecentlyActivatedTunnelNames) ?? []
        if let existingIndex = recentTunnels.firstIndex(of: oldName) {
            recentTunnels[existingIndex] = newName
            userDefaults.set(recentTunnels, forKey: keyRecentlyActivatedTunnelNames)
        }
    }

    static func cleanupTunnels(except tunnelNamesToKeep: Set<String>) {
        guard let userDefaults = RecentTunnelsTracker.userDefaults else { return }
        var recentTunnels = userDefaults.stringArray(forKey: keyRecentlyActivatedTunnelNames) ?? []
        let oldCount = recentTunnels.count
        recentTunnels.removeAll { !tunnelNamesToKeep.contains($0) }
        if oldCount != recentTunnels.count {
            userDefaults.set(recentTunnels, forKey: keyRecentlyActivatedTunnelNames)
        }
    }

    static func recentlyActivatedTunnelNames(limit: Int) -> [String] {
        guard let userDefaults = RecentTunnelsTracker.userDefaults else { return [] }
        var recentTunnels = userDefaults.stringArray(forKey: keyRecentlyActivatedTunnelNames) ?? []
        if limit < recentTunnels.count {
            recentTunnels.removeLast(recentTunnels.count - limit)
        }
        return recentTunnels
    }
}
