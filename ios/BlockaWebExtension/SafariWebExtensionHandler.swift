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
                timestamp: Date(timeIntervalSince1970: 0),
                active: false,
                freemium: false,
                freemiumYoutubeUntil: nil
            )
        markExtensionAsEnabled()

        let response = NSExtensionItem()

        // Format timestamps for JavaScript consumption
        let timestampString = formatDateForJS(status.timestamp)
        let freemiumUntilString = status.freemiumYoutubeUntil.map { formatDateForJS($0) }

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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Handle Go API date formats:
                // "0001-01-01T00:00:00Z" (zero time)
                // "2025-06-17T10:13:00.141629Z" (with microseconds)

                if dateString == "0001-01-01T00:00:00Z" {
                    return Date(timeIntervalSince1970: 0)  // Unix epoch = expired
                }

                // Try standard ISO8601 first
                let iso8601 = ISO8601DateFormatter()
                iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = iso8601.date(from: dateString) {
                    return date
                }

                // Fallback for format without fractional seconds
                iso8601.formatOptions = [.withInternetDateTime]
                if let date = iso8601.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Cannot decode date string \(dateString)"
                    )
                )
            }

            let status = try decoder.decode(JsonBlockaweb.self, from: jsonData)
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
                timestamp: Date(),
                active: true,
                freemium: false,
                freemiumYoutubeUntil: nil
            )

            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(status)
                try jsonData.write(to: fileURL, options: [.atomic])
                os_log(.default, "blockaweb: status updated with timestamp")
            } catch {
                os_log(.error, "blockaweb: failed to write blockaweb JSON: %{public}@", "\(error)")
            }
        }
    }

    /// Format date for JavaScript consumption - handle zero time as clearly expired
    private func formatDateForJS(_ date: Date) -> String {
        if date.timeIntervalSince1970 <= 1 {  // Zero time or very close to it
            return "1970-01-01T00:00:00.000Z"  // Clearly expired for JS
        }

        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso8601.string(from: date)
    }
}
