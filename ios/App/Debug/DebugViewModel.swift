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
//            onMain {
//                let id = Config.shared.accountId()
//                let account = Account(id: id, active_until: "2069-03-15T11:38:38.48383Z", active: true, type: "plus")
//                //SharedActionsService.shared.updateAccount(account)
//            }
        }
    }

    func deactivateAccount() {
        onBackground {
            sleep(5)
            onMain {
//                let id = Config.shared.accountId()
//                let date = self.dateFormatter.string(from: Date().addingTimeInterval(5))
//                let account = Account(id: id, active_until: date, active: true, type: "plus")
                //SharedActionsService.shared.updateAccount(account)
            }
        }
    }

    func resetPacks() {
        //PackRepository.shared.reload()
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
