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

class InboxViewModel: ObservableObject {

    @Published var messages = InboxHistory.empty().messages
    @Published var responding = false
    @Published var input = ""

    private let log = BlockaLogger("Inbox")
    private let service = InboxService.shared

    func fetch() {
        service.setOnUpdated { messages, responding in
            self.messages = messages
            self.responding = responding

            if self.messages.count == 1 {
                self.input = startIntroMessage
            }

            self.objectWillChange.send()
        }
    }

}
