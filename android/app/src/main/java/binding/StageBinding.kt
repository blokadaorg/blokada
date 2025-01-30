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
import service.ContextService
import service.FlutterService
import service.Sheet
import service.SheetService
import ui.utils.openInBrowser

object StageBinding: StageOps {
    private val writeForeground = MutableStateFlow<Boolean?>(null)
    val enteredForegroundHot = writeForeground.filterNotNull().filter { it }

    val route = MutableStateFlow("home")
    val tab = MutableStateFlow(Tab.Home)
    val payload = MutableStateFlow("")

    private val context by lazy { ContextService }
    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }
    private val sheet by lazy { SheetService }
    private val dialog by lazy { AlertDialogService }
    private val scope = GlobalScope

    var showingNavBar = true
    var onShowNavBar: (Boolean) -> Unit = { }
    private var displayingModal: StageModal? = null

    private var previousRoute = ""

    init {
        StageOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
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

            // Special case handling: android wont give us a call when the share sheet is dismissed
            if (displayingModal == StageModal.ADSCOUNTERSHARE) {
                modalDismissed()
            }
        }
    }

    fun setBackground() {
        scope.launch {
            command.execute(CommandName.BACKGROUND)
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
            Sheet.Activated -> StageModal.PERMS
            Sheet.Location -> StageModal.PLUSLOCATIONSELECT
            Sheet.Help -> StageModal.HELP
            Sheet.Custom -> StageModal.CUSTOM
            Sheet.AccountChange -> StageModal.ACCOUNTCHANGE
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
            StageModal.PERMS -> Sheet.Activated
            StageModal.PLUSLOCATIONSELECT -> Sheet.Location
            StageModal.HELP -> Sheet.Help
            StageModal.CUSTOM -> Sheet.Custom
            StageModal.ACCOUNTCHANGE -> Sheet.AccountChange
            else -> null
        }

        if (name != null) {
            sheet.showSheet(name)
        } else {
            // Confirm modal was shown for unknown modals, so the common lib can display it
            scope.launch {
                command.execute(CommandName.MODALSHOWN, modal.name)
            }
        }

        displayingModal = modal
        callback(Result.success(Unit))
    }

    private fun showDialog(modal: StageModal): Boolean {
        val name = when (modal) {
            StageModal.FAULT, StageModal.ACCOUNTINITFAILED -> R.string.error_unknown
            StageModal.ACCOUNTEXPIRED -> R.string.error_account_inactive_generic
            StageModal.ACCOUNTRESTOREFAILED -> R.string.error_payment_inactive_after_restore
            StageModal.ACCOUNTRESTOREIDFAILED -> R.string.error_account_inactive_after_restore
            StageModal.ACCOUNTRESTOREIDOK -> R.string.generic_account_active
            StageModal.ACCOUNTINVALID -> R.string.error_account_invalid
            StageModal.PLUSTOOMANYLEASES -> R.string.error_vpn_too_many_leases
            StageModal.PLUSVPNFAILURE -> R.string.error_vpn
            StageModal.PAYMENTUNAVAILABLE -> R.string.error_payment_not_available
            StageModal.PAYMENTTEMPUNAVAILABLE -> R.string.error_payment_failed
            StageModal.PAYMENTFAILED -> R.string.error_payment_failed_alternative
            else -> null
        }

        val title = when (modal) {
            StageModal.ACCOUNTRESTOREIDOK -> R.string.payment_header_activated
            else -> null
        }

        val action: Pair<String, () -> Unit>? = when (modal) {
            StageModal.ACCOUNTRESTOREIDOK -> null
            else -> {
                context.requireContext().getString(R.string.universal_action_show_log) to {
                    GlobalScope.launch {
                        command.execute(CommandName.LOG)
                    }
                }
            }
        }

        if (name != null) {
            dialog.showAlert(name, title = title, onDismiss = ::modalDismissed, additionalAction = action)
            scope.launch {
                command.execute(CommandName.MODALSHOWN, modal.name)
            }
            return true
        }
        return false
    }

    override fun doDismissModal(callback: (Result<Unit>) -> Unit) {
        if (displayingModal == StageModal.ADSCOUNTERSHARE) {
            modalDismissed()
        } else {
            displayingModal = null
            sheet.dismiss()
            dialog.dismiss()
        }
        callback(Result.success(Unit))
    }

    override fun doOpenLink(url: String, callback: (Result<Unit>) -> Unit) {
        openInBrowser(url)
        callback(Result.success(Unit))
    }

    override fun doHomeReached(callback: (Result<Unit>) -> Unit) {
        context.requireActivity().finish();
        callback(Result.success(Unit))
    }
}