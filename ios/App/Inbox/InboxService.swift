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

class InboxService {

    static let shared = InboxService()

    private let log = BlockaLogger("Inbox")
    private let version = 1

    private var messages = [Message]()

    private init() {
        self.messages = InboxHistory.load().messages
    }

    private var onUpdated = { (messages: [Message], responding: Bool) in }

    func setOnUpdated(callback: @escaping ([Message], Bool) -> Void) {
        onMain {
            self.onUpdated = callback
            callback(self.messages, false)
        }
    }

    func resetChat() {
        InboxHistory.empty().persist()
        messages = InboxHistory.load().messages
        self.onUpdated(messages, false)
    }

    func newMessage(_ text: String) {
        self.messages.append(Message.fromMe(text))
        self.onUpdated(self.messages, true)
        InboxHistory(messages: self.messages, version: self.version).persist()
        processUserMessage(text)
    }

    private func processUserMessage(_ text: String) {
        onBackground {
            sleep(2)

            if let resp = cannedResponses[text] {
                self.playMessages(resp)
            } else {
                var found = false
                for word in text.split(separator: " ") {
                    if !found {
                        let sanitized = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        if let resp = cannedResponses[sanitized] {
                            found = true
                            self.playMessages(resp)
                        }
                    }
                }

                if !found && text.count > 2 {
                    self.playMessages([fallbackMessage])
                } else if !found {
                    self.playMessages(["Ok"])
                }
            }
        }
    }

    private func playMessages(_ messages: [String]) {
        onBackground {
            for msg in messages {
                onMain {
                    self.messages.append(Message.fromBlokada(msg))
                    self.onUpdated(self.messages, !(msg == messages.last ?? "") )
                    InboxHistory(messages: self.messages, version: self.version).persist()
//                    SharedActionsService.shared.newMessage()
                }

                // Give time to read
                sleep(UInt32((Double(msg.count) / 50.0) * 3.0))
            }
        }
    }

}
