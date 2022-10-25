/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package repository

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import model.*
import utils.Ignored
import utils.Logger
import utils.SimpleTasker
import utils.Tasker
import java.util.*

//class AppRepo: Startable {
//
//    // App can be paused with a timer (Date), or indefinitely (nil)
//    private func onPauseApp() { // TODO: also pause plus
//        pauseAppT.setTask { until in
//                return self.appStateHot.first()
//                    .flatMap { it -> AnyPublisher<Ignored, Error> in
//                            // App is already paused, only update timer
//                            if it == .Paused {
//                                guard let until = until else {
//                                // Pause indefinitely instead
//                                return self.timer.cancelTimer(NOTIF_PAUSE)
//                            }
//
//                                return self.timer.createTimer(NOTIF_PAUSE, when: until)
//                            } else if it == .Activated {
//                                guard let until = until else {
//                                // Just pause indefinitely
//                                return self.cloudRepo.setPaused(true)
//                            }
//
//                                return self.cloudRepo.setPaused(true)
//                                    .flatMap { _ in self.timer.createTimer(NOTIF_PAUSE, when: until) }
//                                    .eraseToAnyPublisher()
//                            } else {
//                                return Fail(error: "cannot pause, app in wrong state")
//                                .eraseToAnyPublisher()
//                            }
//                    }
//                    .map { _ in
//                            self.writePausedUntil.send(until)
//                        return true
//                    }
//                    .eraseToAnyPublisher()
//        }
//    }
//
//
//    private func onPause_WaitForExpirationToUnpause() {
//        pausedUntilHot
//            .compactMap { $0 }
//            .flatMap { _ in
//                    // This cold producer will finish once the timer expires.
//                    // It will error out whenever this timer is modified.
//                    self.timer.obtainTimer(NOTIF_PAUSE)
//            }
//            .flatMap { _ in
//                    self.unpauseApp()
//            }
//            .sink(
//                onFailure: { err in Logger.w("AppRepo", "Pause timer failed: \(err)")}
//        )
//        .store(in: &cancellables)
//    }
//
//    private func loadPauseTimerState() {
//        timer.getTimerDate(NOTIF_PAUSE)
//            .tryMap { it in self.writePausedUntil.send(it) }
//            .sink()
//            .store(in: &cancellables)
//    }
//
//}
//
//func getDateInTheFuture(seconds: Int) -> Date {
//    let date = Date()
//    var components = DateComponents()
//    components.setValue(seconds, for: .second)
//    let dateInTheFuture = Calendar.current.date(byAdding: components, to: date)
//    return dateInTheFuture!
//}
//
//class DebugAppRepo: AppRepo {
//
//    private let log = Logger("App")
//    private var cancellables = Set<AnyCancellable>()
//
//    override func start() {
//        super.start()
//
//        writeAppState.sink(
//            onValue: { it in
//                self.log.v("App state: \(it)")
//        }
//        )
//        .store(in: &cancellables)
//    }
//
//}

// Contains "main app state" mostly used in Home screen.
open class AppRepo {

    private val writeAppState = MutableStateFlow<AppState?>(null)
    private val writeWorking = MutableStateFlow<Boolean?>(null)
    private val writePausedUntil = MutableStateFlow<Date?>(null)
    private val writeAccountType = MutableStateFlow<AccountType?>(null)

    val appStateHot = writeAppState.filterNotNull()
    val workingHot = writeWorking.filterNotNull()
    val pausedUntilHot = writePausedUntil
    val accountTypeHot = writeAccountType.filterNotNull()

    private val currentlyOngoingHot by lazy { Repos.processing.currentlyOngoingHot }
    private val accountHot by lazy { Repos.account.accountHot }
    private val cloudRepo by lazy { Repos.cloud }

    //private val timer = TimerService()


    private val pauseAppT = Tasker<Date?, Ignored>("pauseApp")
    private val unpauseAppT = SimpleTasker<Ignored>("unpauseApp")

    open fun start() {
        onPauseApp()
        onUnpauseApp()
        onAnythingThatAffectsAppState_UpdateIt()
        onAccountChange_UpdateAccountType()
        onCurrentlyOngoing_ChangeWorkingState()
        emitWorkingStateOnStart()
    }

    suspend fun pauseApp(until: Date) {
        pauseAppT.send(until)
    }

    suspend fun unpauseApp() {
        unpauseAppT.send()
    }

    // App can be paused with a timer (Date), or indefinitely (nil)
    private fun onPauseApp() {
        pauseAppT.setTask { until ->
            val state = appStateHot.first()
            when (state) {
                // App is already paused, only update timer
                AppState.Paused -> {
                    throw BlokadaException("paused timed not supported")
                }
                AppState.Activated -> {
                    cloudRepo.setPaused(true)
                }
                else -> {
                    throw BlokadaException("cannot pause, app in wrong state")
                }
            }
            writePausedUntil.emit(until)
            true
        }
    }

    private fun onUnpauseApp() {
        unpauseAppT.setTask {
            val state = appStateHot.first()
            when (state) {
                // App is already paused, only update timer
                AppState.Paused, AppState.Deactivated -> {
                    cloudRepo.setPaused(false)
                }
                else -> {
                    throw BlokadaException("cannot unpause, app in wrong state")
                }
            }
            writePausedUntil.emit(null)
            true
        }
    }

    private fun onAnythingThatAffectsAppState_UpdateIt() {
        GlobalScope.launch {
            combine(
                accountTypeHot,
                cloudRepo.dnsProfileActivatedHot,
                cloudRepo.adblockingPausedHot
            ) { accountType, dnsProfileActivated, adblockingPaused ->
                when {
                    !accountType.isActive() -> AppState.Deactivated
                    adblockingPaused -> AppState.Paused
                    dnsProfileActivated -> AppState.Activated
                    else -> AppState.Deactivated
                }
            }
            .collect {
                writeAppState.emit(it)
            }
        }
    }

    private fun onAccountChange_UpdateAccountType() {
        GlobalScope.launch {
            accountHot.map { it.type.toAccountType() }
            .collect {
                writeAccountType.emit(it)
            }
        }
    }

    private fun onCurrentlyOngoing_ChangeWorkingState() {
        // TODO: Same list is in ios
        val tasksThatMarkWorkingState = setOf(
            "accountInit", "refreshAccount", "restoreAccount",
            "pauseApp", "unpauseApp",
            "newPlus", "clearPlus", "switchPlusOn", "switchPlusOff",
            "consumePurchase",
            "plusWorking"
        )

        GlobalScope.launch {
            currentlyOngoingHot
            .map { it.map { i -> i.component }.toSet() }
            .map { it.intersect(tasksThatMarkWorkingState).isNotEmpty() }
            .collect {
                // Async to not cause a choke on the upstream flow
                GlobalScope.launch {
                    if (!it) {
                        // Always delay the non-working state to smooth out any transitions
                        delay(2000)
                    }
                    writeWorking.emit(it)
                }
            }
        }
    }

    private fun emitWorkingStateOnStart() {
        GlobalScope.launch {
            writeAppState.emit(AppState.Deactivated)
            writeWorking.emit(true)
        }
    }

}

class DebugAppRepo: AppRepo() {

    override fun start() {
        super.start()

        GlobalScope.launch {
            appStateHot.collect {
                Logger.e("AppState", "State now: $it")
            }
        }
    }

}