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
import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void

    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil
    let callback: Callback? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let processedItems: [Any]
        
        if ProcessInfo.processInfo.isiOSAppOnMac {
            processedItems = activityItems.compactMap { item in
                if let url = item as? URL {
                    return prepareFileForMacOSSharing(url)
                }
                return item
            }
        } else {
            processedItems = activityItems
        }
        
        let controller = UIActivityViewController(
            activityItems: processedItems,
            applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = callback
        return controller
    }
    
    private func prepareFileForMacOSSharing(_ url: URL) -> Any {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: tempFile.path) {
                try FileManager.default.removeItem(at: tempFile)
            }
            
            try FileManager.default.copyItem(at: url, to: tempFile)
            return tempFile
        } catch {
            print("Failed to prepare file for macOS sharing: \(error)")
            return url
        }
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
