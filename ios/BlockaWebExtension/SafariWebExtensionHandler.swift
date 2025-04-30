//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Created by Johnny Bergström on 2025-04-11.
//

import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
  func beginRequest(with context: NSExtensionContext) {
    let request = context.inputItems.first as? NSExtensionItem

    let profile: UUID?
    if #available(iOS 17.0, macOS 14.0, *) {
      profile = request?.userInfo?[SFExtensionProfileKey] as? UUID
    } else {
      profile = request?.userInfo?["profile"] as? UUID
    }

    let message: Any?
    if #available(iOS 15.0, macOS 11.0, *) {
      message = request?.userInfo?[SFExtensionMessageKey]
    } else {
      message = request?.userInfo?["message"]
    }

    os_log(.default, "Received message from browser.runtime.sendNativeMessage: %@ (profile: %@)", String(describing: message), profile?.uuidString ?? "none")

    var active = false
    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.net.blocka.app") {
      let fileURL = containerURL.appendingPathComponent("blockawebShared.json")
      if FileManager.default.fileExists(atPath: fileURL.path) {
          do {
              let content = try String(contentsOf: fileURL, encoding: .utf8)
              active = content.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
          } catch {
              os_log(.error, "Failed to read blockawebShared.json: %{public}@", "\(error)")
          }
      }
    }

    os_log(.default, "blockaweb active: %{public}@", "\(active)")

    let response = NSExtensionItem()
    if #available(iOS 15.0, macOS 11.0, *) {
      response.userInfo = [ SFExtensionMessageKey: [ "status": [ "active": active ] ] ]
    } else {
      response.userInfo = [ "message": [ "status": [ "active": active ] ] ]
    }

    context.completeRequest(returningItems: [ response ], completionHandler: nil)
  }
}
