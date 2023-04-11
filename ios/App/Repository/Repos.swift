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

// Startable is used for Repos to manually start them (as opposed
// to starting with init()) and have better control on when it
// happens. It is because we need it in tests.
protocol Startable {
    func start()
}

var Repos = RepositoriesSingleton()

class RepositoriesSingleton {
    lazy var permsRepo = PermsRepo()
    lazy var linkRepo = LinkRepo()
}

func startAllRepos() {
    Repos.permsRepo.start()
    Repos.linkRepo.start()

    // Also start some services that probably should be repos?
    Services.netx.start()
    Services.rate.start()
}

func resetReposForDebug() {
    Repos = RepositoriesSingleton()
}

func prepareReposForTesting() {
    resetReposForDebug()
    startAllRepos()
    BlockaLogger.w("Repos", "Ready for testing")
}
