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

class TaskerTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTasker() throws {
        let processor = Tasker<Int, String>(debounce: 0.0)
        processor.setTask { it in
            Just(it)
            .tryMap { it in
                if it == 1 {
                    return "one"
                } else if it == 3 {
                    throw "three not supported"
                } else {
                    return "not one nor three"
                }
            }
            .eraseToAnyPublisher()
        }

        let exp = XCTestExpectation(description: "will answer first request")
        let exp2 = XCTestExpectation(description: "will answer second request")
        let exp3 = XCTestExpectation(description: "will fail third request")
        var cancellables = Set<AnyCancellable>()

        processor.send(1)
        .sink(onValue: { it in
            XCTAssertEqual("one", it)
            exp.fulfill()
        })
        .store(in: &cancellables)

        processor.send(2)
        .sink(onValue: { it in
            XCTAssertEqual("not one nor three", it)
            exp2.fulfill()
        })
        .store(in: &cancellables)

        processor.send(3)
        .sink(onFailure: { err in
            XCTAssertEqual("three not supported", "\(err)")
            exp3.fulfill()
        })
        .store(in: &cancellables)

        wait(for: [exp, exp2, exp3], timeout: 5.0)
        cancellables.forEach { it in it.cancel() }
    }

    func testTaskerWithDebounce() throws {
        let processor = Tasker<Int, String>(debounce: 3.0)
        processor.setTask { it in
            Just(it)
            .tryMap { it in
                if it == 1 {
                    return "one"
                } else {
                    return "not one"
                }
            }
            .eraseToAnyPublisher()
        }

        let exp = XCTestExpectation(description: "will answer first request")
        let exp2 = XCTestExpectation(description: "will answer second request")
        var cancellables = Set<AnyCancellable>()

        processor.send(1)
        .sink(onValue: { it in
            XCTAssertEqual("not one", it) // Expect debounce to ignore "1"
            exp.fulfill()
        })
        .store(in: &cancellables)

        processor.send(2)
        .sink(onValue: { it in
            XCTAssertEqual("not one", it)
            exp2.fulfill()
        })
        .store(in: &cancellables)

        wait(for: [exp, exp2], timeout: 5.0)
        cancellables.forEach { it in it.cancel() }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
