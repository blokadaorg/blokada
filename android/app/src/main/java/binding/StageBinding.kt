/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2023 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import channel.command.CommandName
import channel.stage.StageModal
import channel.stage.StageOps
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import model.Tab
import org.blokada.R
import service.AlertDialogService
import service.FlutterService
import service.Sheet
import service.SheetService

object StageBinding: StageOps {
    private val writeForeground = MutableStateFlow<Boolean?>(null)
    val enteredForegroundHot = writeForeground.filterNotNull().filter { it }

    val route = MutableStateFlow("")
    val tab = MutableStateFlow(Tab.Home)
    val payload = MutableStateFlow("")

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }
    private val sheet by lazy { SheetService }
    private val dialog by lazy { AlertDialogService }
    private val scope = GlobalScope

    var onShowNavBar: (Boolean) -> Unit = { }
    private var displayingModal: StageModal? = null

    private var previousRoute = ""

    init {
        StageOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    fun setActiveTab(tab: Tab) {
        val route = tab.name.lowercase()
        setRoute(route)
    }

    fun setRoute(route: String) {
        previousRoute = this.route.value
        scope.launch {
            command.execute(CommandName.ROUTE, route)
        }
    }

    fun goBack(): Boolean {
        if (route.value.startsWith("http")) {
            setRoute(previousRoute)
            return true
        } else if (route.value.contains("/")) {
            setRoute(route.value.substringBeforeLast("/"))
            return true
        } else {
            return false
        }
    }

    fun setForeground() {
        scope.launch {
            command.execute(CommandName.FOREGROUND)
        }
    }

    fun setBackground() {
        scope.launch {
            command.execute(CommandName.BACKGROUND)
        }
    }

    fun showModal(modal: StageModal) {
        scope.launch {
            command.execute(CommandName.MODALSHOW, modal.name)
        }
    }

    fun dismiss() {
        scope.launch {
            command.execute(CommandName.MODALDISMISS)
        }
    }

    fun sheetShown(sheet: Sheet) {
        val name = when (sheet) {
            Sheet.Payment -> StageModal.PAYMENT
            Sheet.Activated -> StageModal.ONBOARDING
            Sheet.Location -> StageModal.PLUSLOCATIONSELECT
            Sheet.Help -> StageModal.HELP
            Sheet.Custom -> StageModal.CUSTOM
            else -> null
        }

        if (name != null) {
            scope.launch {
                command.execute(CommandName.MODALSHOWN, name.name)
            }
        }
    }

    fun modalDismissed() {
        displayingModal = null
        scope.launch {
            command.execute(CommandName.MODALDISMISSED)
        }
    }

    override fun doShowModal(modal: StageModal, callback: (Result<Unit>) -> Unit) {
        if (displayingModal == modal) return callback(Result.success(Unit))
        if (showDialog(modal)) {
            displayingModal = modal
            return callback(Result.success(Unit))
        }

        val name = when (modal) {
            StageModal.PAYMENT -> Sheet.Payment
            StageModal.ONBOARDING -> Sheet.Activated
            StageModal.PLUSLOCATIONSELECT -> Sheet.Location
            StageModal.HELP -> Sheet.Help
            StageModal.CUSTOM -> Sheet.Custom
            else -> null
        }

        if (name != null) {
            sheet.showSheet(name)
        }

        displayingModal = modal
        callback(Result.success(Unit))
    }

    private fun showDialog(modal: StageModal): Boolean {
        val name = when (modal) {
            StageModal.FAULT, StageModal.ACCOUNTINITFAILED -> R.string.error_unknown
            StageModal.ACCOUNTEXPIRED -> R.string.error_account_inactive
            StageModal.ACCOUNTRESTOREFAILED -> R.string.error_payment_inactive_after_restore
            StageModal.ACCOUNTINVALID -> R.string.error_account_invalid
            StageModal.PLUSTOOMANYLEASES -> R.string.error_vpn_too_many_leases
            StageModal.PLUSVPNFAILURE -> R.string.error_vpn
            StageModal.PAYMENTUNAVAILABLE -> R.string.error_payment_not_available
            StageModal.PAYMENTTEMPUNAVAILABLE -> R.string.error_payment_failed
            StageModal.PAYMENTFAILED -> R.string.error_payment_failed_alternative
            else -> R.string.error_unknown
        }

        dialog.showAlert(name, onDismiss = ::modalDismissed)
        scope.launch {
            command.execute(CommandName.MODALSHOWN, modal.name)
        }
        return true
    }

    override fun doDismissModal(callback: (Result<Unit>) -> Unit) {
        displayingModal = null
        sheet.dismiss()
        dialog.dismiss()
        callback(Result.success(Unit))
    }

    override fun doRouteChanged(path: String, callback: (Result<Unit>) -> Unit) {
        route.value = path
        tab.value = Tab.fromRoute(path)

        if (path.contains("/")) {
            payload.value = path.substringAfter("/")
        } else {
            payload.value = ""
        }

        callback(Result.success(Unit))
    }

    override fun doShowNavbar(show: Boolean, callback: (Result<Unit>) -> Unit) {
        onShowNavBar(show)
        callback(Result.success(Unit))
    }
}