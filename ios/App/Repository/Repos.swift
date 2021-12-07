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
import Combine

var Repos = RepositoriesSingleton()

class RepositoriesSingleton {

    lazy var foregroundRepo = ForegroundRepository()
    lazy var accountRepo = AccountRepository()

}

func resetReposForDebug() {
    Repos = RepositoriesSingleton()
    Repos.foregroundRepo = DebugForegroundRepository()
    Repos.accountRepo = DebugAccountRepository()
}
