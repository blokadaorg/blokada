//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import XCTest
@testable import Mocked

class ModelTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testShortlyBefore() throws {
        let dateFormatter = ISO8601DateFormatter()

        let now = "2022-04-03T19:19:48Z"
        let tenSecAgo = "2022-04-03T19:19:38Z"

        let nowDate = dateFormatter.date(from: now)!
        let tenSecAgoDate = dateFormatter.date(from: tenSecAgo)!

        XCTAssertEqual(nowDate.shortlyBefore(), tenSecAgoDate)
    }

}
