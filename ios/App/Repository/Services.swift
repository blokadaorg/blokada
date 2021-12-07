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

var Services = ServicesSingleton()

class ServicesSingleton {

    fileprivate init() {}

    lazy var persistenceLocal: PersistenceService = LocalStoragePersistenceService()
    lazy var persistenceRemote: PersistenceService = ICloudPersistenceService()
    lazy var persistenceRemoteLegacy: PersistenceService = ICloudPersistenceService()

    lazy var crypto: CryptoService = CryptoServiceMock()

    lazy var http = HttpClientService()
    lazy var api: BlockaApiServiceIn = BlockaApiService2()
    lazy var apiForCurrentUser = BlockaApiCurrentUserService()

}

func resetServices() {
    Services = ServicesSingleton()
}
