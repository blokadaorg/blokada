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

package ui

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.lifecycle.lifecycleScope
import binding.CommandBinding
import binding.CommonBinding
import binding.StageBinding
import channel.command.CommandName
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.blokada.R
import service.ContextService
import service.NetworkMonitorPermissionService
import service.SheetService
import service.TranslationService
import service.VpnPermissionService
import ui.home.FlutterHomeFragment
import utils.now
import utils.Logger


class MainActivity : AppCompatActivity() {

    private val stage by lazy { StageBinding }
    private val commands by lazy { CommandBinding }
    private val sheet by lazy { SheetService }
    private val context by lazy { ContextService }
    private val rate by lazy { CommonBinding }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.apply {
            setFlags(
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            )
        }
        context.setActivityContext(this)
        TranslationService.setup()
        sheet.onShowFragment = { fragment ->
            fragment.show(supportFragmentManager, null)
        }
        sheet.onHideFragment = { fragment ->
            fragment.dismiss()
        }

        rate.onShowRateDialog = { askForReview(this) }

        setContentView(R.layout.activity_main)

        intent?.let {
            handleIntent(it)
        }

        supportFragmentManager.beginTransaction()
            .replace(R.id.container_fragment, FlutterHomeFragment())
            .commit()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
    }

    private var lastOnResume = 0L
    override fun onResume() {
        super.onResume()
        context.setActivityContext(this)
        stage.setForeground()

        // Avoid multiple consecutive quick onResume events
        if (lastOnResume + 5 * 1000 > now()) return
        lastOnResume = now()
    }

    override fun onPause() {
        stage.setBackground()
//        tunnelVM.goToBackground()
        super.onPause()
    }

    override fun onDestroy() {
        context.unsetActivityContext()
        super.onDestroy()
    }

    @Deprecated("This method has been deprecated in favor of using the\n      {@link OnBackPressedDispatcher} via {@link #getOnBackPressedDispatcher()}.\n      The OnBackPressedDispatcher controls how back button events are dispatched\n      to one or more {@link OnBackPressedCallback} objects.")
    override fun onBackPressed() {
        if (stage.goBack()) return
        lifecycleScope.launch {
            commands.execute(CommandName.BACK)
        }
        return
        super.onBackPressed()
    }

    @Deprecated("This method has been deprecated in favor of using the Activity Result API\n      which brings increased type safety via an {@link ActivityResultContract} and the prebuilt\n      contracts for common intents available in\n      {@link androidx.activity.result.contract.ActivityResultContracts}, provides hooks for\n      testing, and allow receiving results in separate, testable classes independent from your\n      activity. Use\n      {@link #registerForActivityResult(ActivityResultContract, ActivityResultCallback)}\n      with the appropriate {@link ActivityResultContract} and handling the result in the\n      {@link ActivityResultCallback#onActivityResult(Object) callback}.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        VpnPermissionService.resultReturned(resultCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        NetworkMonitorPermissionService.resultReturned(grantResults)
    }

    companion object {
        val ACTION = "action"
    }

    private fun askForReview(context: Context) {
        val manager = ReviewManagerFactory.create(context)
        val request = manager.requestReviewFlow()
        request.addOnCompleteListener { request ->
            if (request.isSuccessful) {
                // We got the ReviewInfo object
                val reviewInfo = request.result
                val flow = manager.launchReviewFlow(this, reviewInfo)
                flow.addOnCompleteListener { _ ->
                    // The flow has finished. The API does not indicate whether the user
                    // reviewed or not, or even whether the review dialog was shown. Thus, no
                    // matter the result, we continue our app flow.
                }
            } else {
                // There was some problem, continue regardless of the result.
            }
        }
    }
}