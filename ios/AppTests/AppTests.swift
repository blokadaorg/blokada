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

class AppTests: XCTestCase {

    override func setUpWithError() throws {
        resetFactories()
        resetPubs(debug: true)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let expectation = XCTestExpectation(description: "1")

        let subject = AccountRepository()

        let publisher = Pubs.account
        .sink(
            receiveCompletion: { completion in
                
            },
            receiveValue: { received in
                XCTAssertEqual("rmiqpzizmfuu", received.account.id)
                expectation.fulfill()
            }
        )
        XCTAssertNotNil(publisher)

        wait(for: [expectation], timeout: 5.0)
    }

    func testBlockaApiClients() throws {
        let expectation = XCTestExpectation(description: "1")

        let client = BlockaApiCurrentUserService()

        Pubs.writeAccount.send(AccountWithKeypair(
            account: Account(id: "mockedmocked", active_until: "", active: false, type: "free"),
            keypair: Keypair(privateKey: "priv", publicKey: "pub")
        ))

        let pub = client.getAccountForCurrentUser().sink(
            receiveCompletion: { completion in },
            receiveValue: { it in
                XCTAssertEqual("mockedmocked", it.id)
                expectation.fulfill()
            }
        )
        XCTAssertNotNil(pub)
        
        wait(for: [expectation], timeout: 5.0)
    }

    func testNewAccount() throws {
        let expectation = XCTestExpectation(description: "1")

        // Will return empty result from persistence
        Factories.persistenceRemote = PersistenceServiceMock()
        Factories.persistenceRemoteLegacy = PersistenceServiceMock()

        // Return account with ID that we expect
        Factories.api = BlockaApiServiceMock()

        let repo = AccountRepository()

        let pub = Pubs.account.sink(
            onValue: { it in
                XCTAssertEqual("wearetesting", it.account.id)
                XCTAssert(!it.account.id.isEmpty)
                XCTAssert(!it.keypair.privateKey.isEmpty)
                expectation.fulfill()
            }
        )
        XCTAssertNotNil(pub)

        wait(for: [expectation], timeout: 5.0)
    }

    func testMultipleSubscribers() throws {
        let expectation = XCTestExpectation(description: "1")
        let expectation2 = XCTestExpectation(description: "2")
        let expectation3 = XCTestExpectation(description: "3")
        let expectation4 = XCTestExpectation(description: "4")

        // Will return empty result from persistence
        Factories.persistenceRemote = PersistenceServiceMock()
        Factories.persistenceRemoteLegacy = PersistenceServiceMock()

        // Return account with ID that we expect
        let apiMock = BlockaApiServiceMock()
        let fakeIds = ["111111111111", "222222222222", "333333333333"]
        var getApiCallCount = -1
        apiMock.mockAccount = { id in
            if getApiCallCount == -1 {
                sleep(1)
            }

            getApiCallCount += 1
            return Just(Account(id: id ?? fakeIds[getApiCallCount], active_until: nil, active: false, type: "free"))
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        Factories.api = apiMock

        var firstTime = true
        let pub = Pubs.account.sink(
            onValue: { it in
                if firstTime {
                    XCTAssertEqual("111111111111", it.account.id)
                    expectation.fulfill()
                    firstTime = false
                } else {
                    XCTAssertEqual("mockedmocked", it.account.id)
                    expectation2.fulfill()
                }
            },
            onFinished: { XCTFail("unexpected finish") }
        )
        XCTAssertNotNil(pub)

        var alsoFirstTime = true
        let pub2 = Pubs.account.sink(
            onValue: { it in
                if alsoFirstTime {
                    expectation3.fulfill()
                    alsoFirstTime = false
                } else {
                    XCTAssertEqual("mockedmocked", it.account.id)
                    expectation4.fulfill()
                }
            }
        )
        XCTAssertNotNil(pub2)

        let repo = AccountRepository()
        
        repo.restoreAccount("mockedmocked")

        let pubErr = Pubs.error.sink(
            onValue: { err in
                XCTFail("unexpected error: \(err)")
            }
        )
        XCTAssertNotNil(pubErr)

        wait(for: [expectation, expectation2, expectation3, expectation4], timeout: 5.0)
    }

    func testProposeAccount() throws {
        let expectation = XCTestExpectation(description: "1")

        // Will return empty result from persistence
        Factories.persistenceRemote = PersistenceServiceMock()
        Factories.persistenceRemoteLegacy = PersistenceServiceMock()

        Factories.api = BlockaApiServiceMock()

        let proposedAccount = Account(
            id: "proposed1234", active_until: nil, active: false, type: nil
        )

        let pub = Pubs.account.filter { it in it.account.id == proposedAccount.id}
        .sink(
            onValue: { it in
                XCTAssertEqual("proposed1234", it.account.id)
                expectation.fulfill()
            }
        )
        XCTAssertNotNil(pub)

        let repo = AccountRepository()

        let pub2 = repo.proposeAccount(proposedAccount)
        XCTAssertNotNil(pub2)

        wait(for: [expectation], timeout: 5.0)
    }

    func testPeriodicRefresh() throws {
        var cancellables = Set<AnyCancellable>()
        let expectation = XCTestExpectation(description: "1")

        // Will return empty result from persistence
        Factories.persistenceRemote = PersistenceServiceMock()
        Factories.persistenceRemoteLegacy = PersistenceServiceMock()

        var requests = 0
        let apiMock = BlockaApiServiceMock()
        apiMock.mockAccount = { id in
            requests += 1
            return Just(Account(id: id ?? "trololololol", active_until: nil, active: false, type: "free"))
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        Factories.api = apiMock

        let repo = AccountRepository()

        let bg = DispatchQueue(label: "bg")
        Array(0...10).publisher
        .map { it in it % 2 == 0 }
        .delay(for: 0.3, scheduler: bg)
        .sink(
            onValue: { it in Pubs.writeForeground.send(it) }
        )
        .store(in: &cancellables)

        Pubs.foreground.debounce(for: 2, scheduler: bg)
        .sink(
            onValue: { it in expectation.fulfill() }
        )
        .store(in: &cancellables)

        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(2, requests)
    }
}




