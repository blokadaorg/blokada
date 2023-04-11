//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

var ViewModels = ViewModelsSingleton()

// We don't use the Factory DI here because view models are accessed in views as
// ObservableObjects, and we kinda can't inject them there automatically.
class ViewModelsSingleton {
    lazy var content = ContentViewModel()
    lazy var home = HomeViewModel()
    lazy var tab = TabViewModel()
    lazy var account = AccountViewModel()
    lazy var packs = PacksViewModel()
    lazy var journal = JournalViewModel()
    lazy var custom = CustomViewModel()
    lazy var inbox = InboxViewModel()
    lazy var lease = LeaseListViewModel()
    lazy var payment = PaymentGatewayViewModel()
    lazy var log = LogViewModel()
}
