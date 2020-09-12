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

class DebugViewModel {

    let homeVM: HomeViewModel
    let dateFormatter = DateFormatter()

    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
        dateFormatter.dateFormat = blockaDateFormat
    }

    func activateAccount() {
        onBackground {
            sleep(5)
            onMain {
                let id = Config.shared.accountId()
                let account = Account(id: id, active_until: "2069-03-15T11:38:38.48383Z", active: true)
                SharedActionsService.shared.updateAccount(account)
            }
        }
    }

    func deactivateAccount() {
        onBackground {
            sleep(5)
            onMain {
                let id = Config.shared.accountId()
                let date = self.dateFormatter.string(from: Date().addingTimeInterval(5))
                let account = Account(id: id, active_until: date, active: true)
                SharedActionsService.shared.updateAccount(account)
            }
        }
    }

    func resetPacks() {
        PackService.shared.resetToDefaults()
    }

    func activateFakeAdCounter() {
        self.homeVM.blockedCounter = 0
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            self.homeVM.blockedCounter += Int.random(in: 0 ... ((self.homeVM.blockedCounter * 10) + 1))
            if self.homeVM.blockedCounter > 999_999_999 {
                self.homeVM.blockedCounter = 999_999_999
                timer.invalidate()
            }
        }
    }
}
