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
import UIKit

class SharedActionsService {

    static let shared = SharedActionsService()

    private init() {}

    var newUser = { (done: @escaping Callback<Void>) in }
    var updateAccount = { (account: Account) in }
    var changeGateway = { (new: Gateway) in }
    var refreshLeases = {}
    var present = { (vc: UIActivityViewController) in }
    var newMessage = {}
    var refreshStats = { (ok: @escaping Ok<Void>) in }

}
