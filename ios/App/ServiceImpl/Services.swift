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

// This file defines services configuration for real build.
// Another definition for Mocked builds is in ServiceMock dir.

var Services = ServicesSingleton()

class ServicesSingleton {

    fileprivate init() {}

    lazy var persistenceLocal: PersistenceService = LocalStoragePersistenceService()
    lazy var persistenceRemote: PersistenceService = ICloudPersistenceService()
    lazy var persistenceRemoteLegacy: PersistenceService = ICloudPersistenceService()

    lazy var httpStandard: HttpServiceIn = HttpStandardService()
    lazy var httpProtected: HttpServiceIn = HttpProtectedService()
    //lazy var httpProtected: HttpServiceIn = HttpStandardService()

    lazy var api: BlockaApiServiceIn = BlockaApiService()
    lazy var apiForCurrentUser = BlockaApiCurrentUserService()

    lazy var privateDns: PrivateDnsServiceIn = PrivateDnsService()
    lazy var systemNav = SystemNavService()

    lazy var storeKit = StoreKitService()
    lazy var notification = NotificationService()
    lazy var job = JobService()
    lazy var timer = TimerService()

    lazy var dialog = DialogService()
    lazy var rate = RateService()

    lazy var netx: NetxServiceIn = WgService()
    lazy var quickActions = QuickActionsService()

}

func resetServices() {
    Services = ServicesSingleton()
}
