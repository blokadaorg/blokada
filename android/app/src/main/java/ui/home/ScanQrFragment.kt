/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui.home

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import binding.CommandBinding
import channel.command.CommandName
import io.github.g00fy2.quickie.QRResult
import io.github.g00fy2.quickie.ScanCustomCode
import io.github.g00fy2.quickie.config.ScannerConfig
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import org.blokada.R
import service.Sheet
import ui.BottomSheetFragment
import utils.Logger

class ScanQrFragment : BottomSheetFragment() {
    override val modal: Sheet = Sheet.AccountChange

    private val command by lazy { CommandBinding }

    companion object {
        fun newInstance() = ScanQrFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_loading, container, false)

        startScan()

        return root
    }

    override fun onStart() {
        super.onStart()
    }

    private fun startScan() {
        scanQrCodeLauncher.launch(ScannerConfig.build {
          //setBarcodeFormats(listOf(BarcodeFormat.)) // set interested barcode formats
          setOverlayStringRes(R.string.family_account_qr_header)
          //setOverlayDrawableRes(R.drawable.baseline_qr_code_scanner_24)
          setHapticSuccessFeedback(true)
          //setShowTorchToggle(true)
          setShowCloseButton(true)
          //setKeepScreenOn(true)
        })
    }

    val scanQrCodeLauncher = registerForActivityResult(ScanCustomCode()) { result ->
        Logger.w("MainActivity", "QR Result: $result")
        if (result is QRResult.QRSuccess && result.content.rawValue != null) {
            GlobalScope.launch {
                command.execute(CommandName.FAMILYLINK, result.content.rawValue!!)
            }
        }
        dismiss()
    }
}