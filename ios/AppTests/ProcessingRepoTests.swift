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

class ProcessingRepoTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testShouldKeepTrackOfOngoingComponents() throws {
        // Don't call here: prepareReposForTesting()
        resetReposForDebug()

        let exp = XCTestExpectation(description: "will keep track of ongoing components")
        var counter = 0
        let processingRepo = Repos.processingRepo as! DebugProcessingRepo
        let pub = processingRepo.currentlyOngoingHot.sink(
            onValue: { it in
                counter += 1
                if counter == 2 {
                    XCTAssertEqual(2, it.count)
                } else if counter == 4 {
                    XCTAssert(it.isEmpty)
                    exp.fulfill()
                }
            }
        )

        // Should ignore redundant or irrelevant states
        processingRepo.injectOngoing(ComponentOngoing(component: "Test1", ongoing: true))
        processingRepo.injectOngoing(ComponentOngoing(component: "Test1", ongoing: true))
        processingRepo.injectOngoing(ComponentOngoing(component: "Test2", ongoing: true))
        processingRepo.injectOngoing(ComponentOngoing(component: "Test1", ongoing: false))
        processingRepo.injectOngoing(ComponentOngoing(component: "Test2", ongoing: false))
        processingRepo.injectOngoing(ComponentOngoing(component: "Test2", ongoing: false))
        processingRepo.injectOngoing(ComponentOngoing(component: "Test3", ongoing: false))

        wait(for: [exp], timeout: 5.0)
        pub.cancel()
    }

}
