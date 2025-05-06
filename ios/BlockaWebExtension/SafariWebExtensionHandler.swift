//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Created by Johnny Bergström on 2025-04-11.
//

import SafariServices
import os.log

// Used both ways, by the app to provide its status to the exception,
// and by the exception to provide a ping its alive.
// For the former, timestamp is account expiration.
// For the latter, timestamp is last ping.
struct JsonBlockaweb: Codable {
    let timestamp: Date
    let active: Bool
}

let blockaDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
let blockaDateFormatter = initDateFormatter()
let blockaDecoder = initJsonDecoder()
let blockaEncoder = initJsonEncoder()

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

    os_log(.default, "blockaweb: received message from browser.runtime.sendNativeMessage: %@ (profile: %@)", String(describing: message), profile?.uuidString ?? "none")

    let active = checkAppStatus()
    markExtensionAsEnabled()

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
          let fileURL = containerURL.appendingPathComponent("blockaweb.app.status.json")
          if FileManager.default.fileExists(atPath: fileURL.path) {
              do {
                  let content = try String(contentsOf: fileURL, encoding: .utf8)

                  if let jsonData = content.data(using: .utf8) {
                      do {
                          let status = try blockaDecoder.decode(JsonBlockaweb.self, from: jsonData)
                          os_log(.default, "blockaweb: got app status: %{public}@", "\(status)")
                          return (status.active && status.timestamp > Date())
                      } catch {
                          os_log(.error, "blockaweb: failed to decode app.json: %{public}@", "\(error)")
                      }
                  }
              } catch {
                  os_log(.error, "blockaweb: failed to read app.json: %{public}@", "\(error)")
              }
          }
        }
        return false
    }

    // Saves a timestamp for when the extension was called last time (for the app to check)
    func markExtensionAsEnabled() {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.net.blocka.app") {
            let fileURL = containerURL.appendingPathComponent("blockaweb.ping.json")
            let status = JsonBlockaweb(timestamp: Date(), active: true)

            do {
                let jsonData = try blockaEncoder.encode(status)
                try jsonData.write(to: fileURL, options: [.atomic])
                os_log(.default, "blockaweb: status updated with timestamp")
            } catch {
                os_log(.error, "blockaweb: failed to write blockaweb JSON: %{public}@", "\(error)")
            }
        }
    }
}

func initDateFormatter() -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = blockaDateFormat
    return dateFormatter
}

func initJsonDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .formatted(blockaDateFormatter)
    return decoder
}

func initJsonEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .formatted(blockaDateFormatter)
    return encoder
}
