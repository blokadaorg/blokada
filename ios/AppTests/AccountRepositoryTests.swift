//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Kar
//

import XCTest
import Combine
@testable import Mocked

class AccountRepositoryTests: XCTestCase {

    override func setUpWithError() throws {
        Mocks.resetEverythingForTest()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testShouldCreateNewAccountOnInitWhenEmptyPersistence() throws {
        Mocks.useEmptyPersistence()

        // Return account with ID that we expect
        let apiMock = BlockaApiServiceMock()
        apiMock.mockAccount = { id in Mocks.justAccount("wearetesting") }
        Services.api = apiMock

        resetReposForDebug()

        let exp = XCTestExpectation(description: "will return account in publisher")
        let pub = Repos.accountRepo.account.sink(
            onValue: { it in
                XCTAssertEqual("wearetesting", it.account.id)
                XCTAssert(!it.account.id.isEmpty)
                XCTAssert(!it.keypair.privateKey.isEmpty)
                exp.fulfill()
            }
        )

        wait(for: [exp], timeout: 5.0)
        pub.cancel()
    }

    func testMultipleSubscribersShouldReceiveSameThings() throws {
        Mocks.useEmptyPersistence()

        // Return account with ID that we expect
        let apiMock = BlockaApiServiceMock()
        let mockIds = ["111111111111", "222222222222", "333333333333"]
        var getApiCallCount = -1
        apiMock.mockAccount = { id in
            if getApiCallCount == -1 {
                sleep(1) // First request respond slow to put responses out of order
            }

            getApiCallCount += 1
            return Mocks.justAccount(id ?? mockIds[getApiCallCount])
        }
        Services.api = apiMock

        var cancellables = Set<AnyCancellable>()
        let expectations = Array(0...3).map { it in XCTestExpectation(description: "accounts published in order") }

        resetReposForDebug()

        // First subscriber should get all accounts in order
        var firstResult = true
        Repos.accountRepo.account.sink(
            onValue: { it in
                if firstResult {
                    XCTAssertEqual("111111111111", it.account.id)
                    expectations[0].fulfill()
                    firstResult = false
                } else {
                    XCTAssertEqual("mockedmocked", it.account.id)
                    expectations[1].fulfill()
                }
            }
        )
        .store(in: &cancellables)

        // Second subsrciber as well
        var firstResultForSecondSubscriber = true
        Repos.accountRepo.account.sink(
            onValue: { it in
                if firstResultForSecondSubscriber {
                    XCTAssertEqual("111111111111", it.account.id)
                    expectations[2].fulfill()
                    firstResultForSecondSubscriber = false
                } else {
                    XCTAssertEqual("mockedmocked", it.account.id)
                    expectations[3].fulfill()
                }
            }
        )
        .store(in: &cancellables)

        // Restoring account should return the second account (first one is from creating new account automatically)
        Repos.accountRepo.restoreAccount("mockedmocked")

        wait(for: expectations, timeout: 5.0)
        cancellables.forEach { it in it.cancel() }
    }

    func testProposedAccountShouldBePublished() throws {
        Mocks.useEmptyPersistence()
        Services.api = BlockaApiServiceMock()

        var cancellables = Set<AnyCancellable>()
        let exp = XCTestExpectation(description: "published proposed account")
        let proposedAccount = Mocks.account("proposed1234")

        resetReposForDebug()

        Repos.accountRepo.account
        .filter { it in it.account.id == proposedAccount.id }
        .sink(
            onValue: { it in
                XCTAssertEqual("proposed1234", it.account.id)
                exp.fulfill()
            }
        )
        .store(in: &cancellables)

        Repos.accountRepo.proposeAccount(proposedAccount)

        wait(for: [exp], timeout: 5.0)
        cancellables.forEach { it in it.cancel() }
    }

    func testPeriodicRefreshShouldMakeJustEnoughRequests() throws {
        Mocks.useEmptyPersistence()

        var requests = 0
        let apiMock = BlockaApiServiceMock()
        apiMock.mockAccount = { id in
            requests += 1
            return Mocks.justAccount(id ?? "trololololol")
        }
        Services.api = apiMock

        var cancellables = Set<AnyCancellable>()
        let exp = XCTestExpectation(description: "finished sending mocked foreground events")
        let bg = DispatchQueue(label: "bg")

        resetReposForDebug()

        let foregroundDebug = Repos.foregroundRepo as! DebugForegroundRepository

        // Shoot 10 quick foreground/background events to see how they are processed by the repo
        Array(0...10).publisher
        .map { it in it % 2 == 0 }
        .delay(for: 0.3, scheduler: bg)
        .sink(
            onValue: { it in foregroundDebug.injectForeground(isForeground: it) }
        )
        .store(in: &cancellables)

        Repos.foregroundRepo.foreground
        .debounce(for: 2, scheduler: bg) // Debounce to wait a bit before checking the expectation
        .sink(
            onValue: { it in exp.fulfill() }
        )
        .store(in: &cancellables)

        wait(for: [exp], timeout: 5.0)
        XCTAssertEqual(1 + 1, requests) // 1 create account + 1 foreground refresh
    }
}




