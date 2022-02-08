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

import XCTest
import Combine
@testable import Mocked

class CombineTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCurrentValueSubjectAndFirst() throws {
        let s = CurrentValueSubject<String?, Never>(nil)
        s.send("Hello")

        let exp = XCTestExpectation(description: "will return the most recent item imediatelly")
        var cancellables = Set<AnyCancellable>()

        s.first()
        .sink(onValue: { it in
            XCTAssertEqual("Hello", it)
            exp.fulfill()
        })
        .store(in: &cancellables)

        wait(for: [exp], timeout: 5.0)
        cancellables.forEach { it in it.cancel() }
    }

}
