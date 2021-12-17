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

// Contains "main app state" mostly used in Home screen.
class AppRepo {

    var appStateHot: AnyPublisher<AppState, Never> {
        self.writeAppState.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var workingHot: AnyPublisher<Bool, Never> {
        self.writeWorking.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var pausedUntilHot: AnyPublisher<Date?, Never> {
        self.writePausedUntil.removeDuplicates().eraseToAnyPublisher()
    }

    var accountType: AnyPublisher<AccountType, Never> {
        self.writeAccountType.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    fileprivate let writeAppState = CurrentValueSubject<AppState?, Never>(nil)
    fileprivate let writeWorking = CurrentValueSubject<Bool?, Never>(nil)
    fileprivate let writePausedUntil = CurrentValueSubject<Date?, Never>(nil)
    fileprivate let writeAccountType = CurrentValueSubject<AccountType?, Never>(nil)

    private lazy var timer = Services.timer

    private lazy var accountHot = Repos.accountRepo.accountHot
    private lazy var cloudRepo = Repos.cloudRepo

    private var cancellables = Set<AnyCancellable>()
    private let recentAccountType = Atomic<AccountType>(AccountType.Libre)

    init() {
        onAnythingThatAffectsAppStateUpdateIt()
        onAccountChangeUpdateAccountType()
        onPauseWaitForExpirationToUnpause()
        loadPauseTimerState()
    }

    func pauseApp(until: Date?) -> AnyPublisher<Ignored, Error> {
        let until = until ?? getDateInTheFuture(seconds: 60 * 60)
        return appStateHot.first()
        .flatMap { it -> AnyPublisher<Ignored, Error> in
            if it == .Paused {
                // App is already paused, only update timer
                return self.timer.createTimer(NOTIF_PAUSE, when: until)
            } else if it == .Activated {
                return self.cloudRepo.setPaused(true)
                .flatMap { _ in self.timer.createTimer(NOTIF_PAUSE, when: until) }
                .eraseToAnyPublisher()
            } else {
                return Fail(error: "cannot pause, app in wrong state")
                .eraseToAnyPublisher()
            }
        }
        .map { _ in
            self.writePausedUntil.send(until)
            return true
        }
        .eraseToAnyPublisher()
    }

    func unpauseApp() -> AnyPublisher<Ignored, Error> {
        return appStateHot.first()
        .flatMap { it -> AnyPublisher<Ignored, Error> in
            if it == .Paused {
                return self.cloudRepo.setPaused(false)
                .flatMap { _ in self.timer.cancelTimer(NOTIF_PAUSE) }
                .eraseToAnyPublisher()
            } else {
                return Fail(error: "cannot unpause, app in wrong state")
                .eraseToAnyPublisher()
            }
        }
        .map { _ in
            self.writePausedUntil.send(nil)
            return true
        }
        .eraseToAnyPublisher()
    }

    private func onAnythingThatAffectsAppStateUpdateIt() {
        Publishers.CombineLatest3(
            accountType,
            cloudRepo.dnsProfileActivatedHot,
            cloudRepo.adblockingPausedHot
        )
        .map { it -> AppState in
            let (accountType, dnsProfileActivated, adblockingPaused) = it

            if !accountType.isActive() {
                return AppState.Deactivated
            }

            if adblockingPaused {
                return AppState.Paused
            }

            if dnsProfileActivated {
                return AppState.Activated
            }

            return AppState.Deactivated
        }
        .sink(onValue: { it in self.writeAppState.send(it) })
        .store(in: &cancellables)
    }

    private func onAccountChangeUpdateAccountType() {
        accountHot.compactMap { it in it.account.type }
        .map { it in mapAccountType(it) }
        .sink(onValue: { it in
                self.recentAccountType.value = it
                self.writeAccountType.send(it)
        })
        .store(in: &cancellables)
    }

    private func onPauseWaitForExpirationToUnpause() {
        pausedUntilHot
        .compactMap { $0 }
        .flatMap { _ in
            // This cold producer will finish once the timer expires.
            // It will error out whenever this timer is modified.
            self.timer.obtainTimer(NOTIF_PAUSE)
        }
        .flatMap { _ in
            self.unpauseApp()
        }
        .sink()
        .store(in: &cancellables)
    }

    private func loadPauseTimerState() {
        timer.getTimerDate(NOTIF_PAUSE)
        .tryMap { it in self.writePausedUntil.send(it) }
        .sink()
        .store(in: &cancellables)
    }

}

func getDateInTheFuture(seconds: Int) -> Date {
    let date = Date()
    var components = DateComponents()
    components.setValue(seconds, for: .second)
    let dateInTheFuture = Calendar.current.date(byAdding: components, to: date)
    return dateInTheFuture!
}
