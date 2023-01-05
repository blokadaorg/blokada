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

    lazy var processingRepo = ProcessingRepo()
    lazy var stageRepo = StageRepo()
    lazy var navRepo = NavRepo()
    lazy var httpRepo = HttpRepo()
    lazy var accountRepo = AccountRepo()
    lazy var cloudRepo = CloudRepo()
    lazy var appRepo = AppRepo()
    lazy var paymentRepo = PaymentRepo()
    lazy var activityRepo = ActivityRepo()
    lazy var statsRepo = StatsRepo()
    lazy var packRepo = PackRepo()
    lazy var sheetRepo = SheetRepo()
    lazy var permsRepo = PermsRepo()
    lazy var gatewayRepo = GatewayRepo()
    lazy var leaseRepo = LeaseRepo()
    lazy var netxRepo = NetxRepo()
    lazy var plusRepo = PlusRepo()
    lazy var linkRepo = LinkRepo()

}

func startAllRepos() {
    Repos.processingRepo.start()
    Repos.stageRepo.start()
    Repos.navRepo.start()
    Repos.httpRepo.start()
    Repos.accountRepo.start()
    Repos.cloudRepo.start()
    Repos.appRepo.start()
    Repos.paymentRepo.start()
    Repos.activityRepo.start()
    Repos.statsRepo.start()
    Repos.packRepo.start()
    Repos.sheetRepo.start()
    Repos.permsRepo.start()
    Repos.gatewayRepo.start()
    Repos.leaseRepo.start()
    Repos.netxRepo.start()
    Repos.plusRepo.start()
    Repos.linkRepo.start()

    // Also start some services that probably should be repos?
    Services.netx.start()
    Services.rate.start()
}

func resetReposForDebug() {
    Repos = RepositoriesSingleton()
    Repos.processingRepo = DebugProcessingRepo()
    Repos.stageRepo = DebugStageRepo()
    Repos.accountRepo = DebugAccountRepo()
    Repos.appRepo = DebugAppRepo()
    Repos.cloudRepo = DebugCloudRepo()
    Repos.sheetRepo = DebugSheetRepo()
    Repos.netxRepo = DebugNetxRepo()
}

func prepareReposForTesting() {
    resetReposForDebug()
    startAllRepos()
    BlockaLogger.w("Repos", "Ready for testing")
}
