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

struct Message: Codable, Identifiable {
    let id: String
    let text: String
    let date: Date
    let isMe: Bool
}

extension Message {
    static func fromBlokada(_ text: String, date: Date = Date()) -> Message {
        Message(id: UUID().uuidString, text: text, date: date, isMe: false)
    }

    static func fromMe(_ text: String, date: Date = Date()) -> Message {
        Message(id: UUID().uuidString, text: text, date: date, isMe: true)
    }
}

extension Message: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Message: Equatable {
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

let introMessage = "Hi! I'm Blocky, your Blokada assistant. Should I introduce you to the Inbox?";

let fallbackMessage = "Try asking me about: adblocking, dns, battery.";

let startIntroMessage = "Go ahead!";

let cannedResponses = [
    startIntroMessage: introMessages,
    "adblocking": adblockingMessages,
    "dns": dnsMessages,
    "battery": batteryMessages
]

private let introMessages = [
    "I am a bot, and I know a lot about how to use Blokada. I will also let you know about important news from the community.",
    "Just text me if you need help, or want to learn more about Blokada.",
    "Would you like to ask me anything?"
]

private let adblockingMessages = [
    "Blokada is famous for its adblocking ability. Once you activate the app by tapping the big circle button in Home tab, it will become blue.",
    "It means, adblocking is active now. Blokada can block ads in Safari, as well as in other apps.",
    "Just remember, you may still see some ads, because adblocking on mobile devices is never 100% accurate.",
    "That said, you should notice a difference, and the Activity tab should contain some red (blocked) entries."
]

private let dnsMessages = [
    "DNS means Domain Name System. It is how your device knows where to find websites you want to visit.",
    "Sadly, most of the Internet is still using unencrypted DNS, which is a risk for your data and privacy.",
    "Blokada forces your device to use encrypted DNS, whenever it is active (the blue circle).",
    "You may choose among several reputable encrypted DNS servers, in Settings tab."
]

private let batteryMessages = [
    "Blokada is as efficient as possible, so you should not experience battery drain.",
    "However, you may expect to see Blokada in your battery usage list.",
    "This happens because whenever you activate Blokada, it creates a fake VPN to block ads.",
    "Because of this, all apps that send data, will do so through that VPN, and iOS will attribute their battery usage to Blokada."
]

struct InboxHistory: Codable {
    let messages: [Message]
    let version: Int?
}

extension InboxHistory {
    func persist() {
        if let jsonified = self.toJson() {
            UserDefaults.standard.set(jsonified, forKey: "inbox.history")
        } else {
            BlockaLogger.w("Inbox", "Could not convert chat to json")
        }
    }

    static func load() -> InboxHistory {
        let result = UserDefaults.standard.string(forKey: "inbox.history")
           guard let stringData = result else {
               return InboxHistory.empty()
           }

           let jsonData = stringData.data(using: .utf8)
           guard let json = jsonData else {
               BlockaLogger.e("Inbox", "Failed getting chat json")
               return InboxHistory.empty()
           }

           do {
               return try blockaDecoder.decode(InboxHistory.self, from: json)
           } catch {
               BlockaLogger.e("Inbox", "Failed decoding chat json".cause(error))
               return InboxHistory.empty()
           }
    }

    static func empty() -> InboxHistory {
        InboxHistory(messages: [
            Message.fromBlokada(introMessage)
        ], version: 1)
    }
}
