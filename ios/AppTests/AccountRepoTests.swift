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

class AccountRepoTests: XCTestCase {

    override func setUpWithError() throws {
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

        prepareReposForTesting()

        let exp = XCTestExpectation(description: "will return account in publisher")
        let pub = Repos.accountRepo.accountHot.sink(
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

    func testShouldNotCreateNewAccountIfPersisted() throws {
        let exp = XCTestExpectation(description: "will load account from persistence")
        let exp2 = XCTestExpectation(description: "will load keypair from persistence")
        Mocks.useEmptyPersistence()
        let mock = PersistenceServiceMock()
        mock.mockGetString = { forKey in
            if forKey == "account" {
                exp.fulfill()
                return Just(Mocks.account("123456789012"))
                .encode(encoder: blockaEncoder)
                .tryMap { it -> String in
                    guard let it = String(data: it, encoding: .utf8) else {
                        throw "account mock: could not encode json data to string"
                    }
                    return it
                }
                .eraseToAnyPublisher()
            } else {
                return Fail<String, Error>(error: CommonError.emptyResult)
                    .eraseToAnyPublisher()
            }
        }
        let mock2 = PersistenceServiceMock()
        mock2.mockGetString = { forKey in
            if forKey == "keypair" {
                exp2.fulfill()
                return Just(Keypair(privateKey: "mock-priv", publicKey: "mock-pub"))
                .encode(encoder: blockaEncoder)
                .tryMap { it -> String in
                    guard let it = String(data: it, encoding: .utf8) else {
                        throw "keypair mock: could not encode json data to string"
                    }
                    return it
                }
                .eraseToAnyPublisher()
            } else {
                return Fail<String, Error>(error: CommonError.emptyResult)
                    .eraseToAnyPublisher()
            }
        }
        Services.persistenceRemote = mock
        Services.persistenceLocal = mock2

        // Return account with ID that we expect
        let apiMock = BlockaApiServiceMock()
        apiMock.mockAccount = { id in
            XCTAssertEqual("123456789012", id)
            return Mocks.justAccount("123456789012")
        }
        Services.api = apiMock

        prepareReposForTesting()

        let exp3 = XCTestExpectation(description: "will not create account")
        let pub = Repos.accountRepo.accountHot.sink(
            onValue: { it in
                XCTAssertEqual("123456789012", it.account.id)
                XCTAssert(!it.account.id.isEmpty)
                XCTAssert(!it.keypair.privateKey.isEmpty)
                exp3.fulfill()
            }
        )

        wait(for: [exp, exp2, exp3], timeout: 5.0)
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

        prepareReposForTesting()

        // First subscriber should get all accounts in order
        var firstResult = true
        Repos.accountRepo.accountHot.sink(
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
        Repos.accountRepo.accountHot.sink(
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

        prepareReposForTesting()

        Repos.accountRepo.accountHot
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

        prepareReposForTesting()

        let foregroundDebug = Repos.stageRepo as! DebugStageRepo

        // Shoot 10 quick foreground/background events to see how they are processed by the repo
        Array(0...10).publisher
        .map { it in it % 2 == 0 }
        .delay(for: 0.3, scheduler: bg)
        .sink(
            onValue: { it in foregroundDebug.injectForeground(isForeground: it) }
        )
        .store(in: &cancellables)

        Repos.stageRepo.stageHot
        .debounce(for: 2, scheduler: bg) // Debounce to wait a bit before checking the expectation
        .sink(
            onValue: { it in exp.fulfill() }
        )
        .store(in: &cancellables)

        wait(for: [exp], timeout: 5.0)
        // 1 create account + not too many fg refreshes
        XCTAssert(requests >= 2 && requests <= 5)
        cancellables.forEach { it in it.cancel() }
    }
}




