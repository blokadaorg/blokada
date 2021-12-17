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

    lazy var envRepo = EnvRepo()
    lazy var processingRepo = ProcessingRepo()
    lazy var stageRepo = StageRepo()
    lazy var navRepo = NavRepo()
    lazy var accountRepo = AccountRepo()
    lazy var cloudRepo = CloudRepo()
    lazy var appRepo = AppRepo()
    lazy var paymentRepo = PaymentRepo()
    lazy var activityRepo = ActivityRepo()

}

func resetReposForDebug() {
    Repos = RepositoriesSingleton()
    Repos.processingRepo = DebugProcessingRepo()
    Repos.stageRepo = DebugStageRepo()
    Repos.accountRepo = DebugAccountRepo()
    Repos.cloudRepo = DebugCloudRepo()
}
