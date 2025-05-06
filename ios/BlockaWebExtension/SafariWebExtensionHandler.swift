//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Created by Johnny Bergström on 2025-04-11.
//

import SafariServices
import os.log

struct JsonBlockaweb: Codable {
    let accountActiveUntil: Date
    let appActive: Bool
}

let blockaDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
let blockaDateFormatter = initDateFormatter()
let blockaDecoder = initJsonDecoder()

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

    var active = checkAppStatus()
    os_log(.default, "blockaweb active: %{public}@", "\(active)")

    let response = NSExtensionItem()
    if #available(iOS 15.0, macOS 11.0, *) {
      response.userInfo = [ SFExtensionMessageKey: [ "status": [ "active": active ] ] ]
    } else {
      response.userInfo = [ "message": [ "status": [ "active": active ] ] ]
    }

    context.completeRequest(returningItems: [ response ], completionHandler: nil)
  }

    // Loads the app status from a shared file (updated by app)
    func checkAppStatus() -> Bool {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.net.blocka.app") {
          let fileURL = containerURL.appendingPathComponent("app.json")
          if FileManager.default.fileExists(atPath: fileURL.path) {
              do {
                  let content = try String(contentsOf: fileURL, encoding: .utf8)

                  if let jsonData = content.data(using: .utf8) {
                      do {
                          let status = try blockaDecoder.decode(JsonBlockaweb.self, from: jsonData)
                          os_log(.default, "blockaweb status: %{public}@", "\(status)")
                          return (status.appActive && status.accountActiveUntil > Date())
                      } catch {
                          os_log(.error, "Failed to decode app.json: %{public}@", "\(error)")
                      }
                  }
              } catch {
                  os_log(.error, "Failed to read app.json: %{public}@", "\(error)")
              }
          }
        }
        return false
    }
}

func initDateFormatter() -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = blockaDateFormat
    return dateFormatter
}

func initJsonDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let dateFormatter = blockaDateFormatter
    decoder.dateDecodingStrategy = .formatted(dateFormatter)
    return decoder
}
