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

class TabViewModel : ObservableObject {

    @Published var activeTab = "home" {
        didSet {
            // This is how we navigate back from multi level navigation
            self.selection = nil
        }
    }

    @Published var activityBadge: Int? = nil

    @Published var packsBadge: Int? = nil

    @Published var inboxBadge: Int = -1 {
        didSet {
            UserDefaults.standard.set(inboxBadge, forKey: "badge.inbox")
        }
    }

    @Published var settingsBadge: Int = -1 {
        didSet {
            UserDefaults.standard.set(settingsBadge, forKey: "badge.settings")
        }
    }

    @Published var selection: String? = nil

    init() {
        SharedActionsService.shared.newMessage = {
            if self.selection != "inbox" {
                self.setInboxUnseen()
            }
        }
    }

    func load() {
        self.inboxBadge = UserDefaults.standard.integer(forKey: "badge.inbox")
        self.settingsBadge = UserDefaults.standard.integer(forKey: "badge.settings")
        if self.inboxBadge == 0 {
            // First run, set to 1 to highlight the inbox section
            setInboxUnseen()
        }
    }

    func setInboxUnseen() {
        if self.inboxBadge > 0 {
            self.inboxBadge += 1
        } else {
            self.inboxBadge = 1
        }

        self.settingsBadge = self.inboxBadge
    }

    func seenInbox() {
        self.inboxBadge = -1
        self.settingsBadge = -1
    }

    func hasInboxBadge() -> Bool {
        return inboxBadge > 0
    }
}
