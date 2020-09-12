//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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

    private let log = Logger("Inbox")
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
