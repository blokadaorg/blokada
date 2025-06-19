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
    let freemium: Bool?
    let freemiumYoutubeUntil: Date?

    enum CodingKeys: String, CodingKey {
        case timestamp, active, freemium
        case freemiumYoutubeUntil = "freemium_youtube_until"
    }
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

        os_log(
            .default,
            "blockaweb: received message from browser.runtime.sendNativeMessage: %@ (profile: %@)",
            String(describing: message), profile?.uuidString ?? "none")

        // Decode app status set by main app.
        let status =
            decodeAppStatus()
            ?? JsonBlockaweb(
                timestamp: Date(), active: false, freemium: false, freemiumYoutubeUntil: nil)
        markExtensionAsEnabled()

        let response = NSExtensionItem()
        // Format timestamp as ISO string for JSON serialization
        let timestampString = blockaDateFormatter.string(from: status.timestamp)
        let freemiumUntilString = status.freemiumYoutubeUntil.map {
            blockaDateFormatter.string(from: $0)
        }

        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [
                SFExtensionMessageKey: [
                    "status": [
                        "active": status.active,
                        "timestamp": timestampString,
                        "freemium": status.freemium ?? false,
                        "freemiumYoutubeUntil": freemiumUntilString as Any,
                    ]
                ]
            ]
        } else {
            response.userInfo = [
                "message": [
                    "status": [
                        "active": status.active,
                        "timestamp": timestampString,
                        "freemium": status.freemium ?? false,
                        "freemiumYoutubeUntil": freemiumUntilString as Any,
                    ]
                ]
            ]
        }

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    /// Decode the shared app status JSON into our model
    private func decodeAppStatus() -> JsonBlockaweb? {
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.net.blocka.app")
        else {
            return nil
        }
        let fileURL = containerURL.appendingPathComponent("blockaweb.app.status.json")
        guard FileManager.default.fileExists(atPath: fileURL.path),
            let content = try? String(contentsOf: fileURL, encoding: .utf8),
            let jsonData = content.data(using: .utf8)
        else {
            return nil
        }
        do {
            let status = try blockaDecoder.decode(JsonBlockaweb.self, from: jsonData)
            return status
        } catch {
            os_log(.error, "blockaweb: failed to decode app status: %{public}@", "\(error)")
            return nil
        }
    }

    // Saves a timestamp for when the extension was called last time (for the app to check)
    func markExtensionAsEnabled() {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.blocka.app")
        {
            let fileURL = containerURL.appendingPathComponent("blockaweb.ping.json")
            let status = JsonBlockaweb(
                timestamp: Date(), active: true, freemium: false, freemiumYoutubeUntil: nil)

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
